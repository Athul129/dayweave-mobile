import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';
import 'preference_duration_option.dart';
import 'preferences_preview_data.dart';

Future<void> showPreferencesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PreferencesSheet(),
    );

class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({super.key});

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  int selectedMinutes = 30;
  bool customSelected = false;
  PreferencesPreviewState previewState = PreferencesPreviewState.preset;
  late final TextEditingController customController = TextEditingController();
  final customFocusNode = FocusNode();
  final customFieldKey = GlobalKey();

  @override
  void dispose() {
    customFocusNode.removeListener(_keepCustomFieldVisible);
    customController.dispose();
    customFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    customFocusNode.addListener(_keepCustomFieldVisible);
  }

  void _keepCustomFieldVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !customFocusNode.hasFocus) return;
      final fieldContext = customFieldKey.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          alignment: .25,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Material(
          color: DayweaveColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                DayweaveSpacing.xl, 12, DayweaveSpacing.xl, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: DayweaveColors.line,
                          borderRadius: DayweaveRadii.sm))),
              const SizedBox(height: 18),
              Text('Preferences',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontFamily: 'Fraunces', fontSize: 26)),
              const SizedBox(height: 7),
              Text('Choose the starting length for new tasks.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 22),
              Text('Default task duration',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14)),
              const SizedBox(height: 10),
              _options(),
              if (customSelected)
                Container(
                  key: customFieldKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Custom minutes',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: customController,
                        focusNode: customFocusNode,
                        enabled: previewState !=
                            PreferencesPreviewState.invalidRange,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '35',
                          errorText: _errorText,
                          suffixIcon: const Icon(Icons.unfold_more, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _options() => LayoutBuilder(builder: (context, constraints) {
        final options = [
          ('15 minutes', false),
          ('30 minutes', false),
          ('45 minutes', false),
          ('60 minutes', false),
        ];
        return Wrap(spacing: 8, runSpacing: 8, children: [
          ...options.map((option) => SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: PreferenceDurationOption(
                  label: option.$1,
                  selected: !customSelected &&
                      selectedMinutes.toString() == option.$1.split(' ').first,
                  onTap: () => setState(() {
                        customSelected = false;
                        selectedMinutes = int.parse(option.$1.split(' ').first);
                      })))),
          SizedBox(
              width: constraints.maxWidth,
              child: PreferenceDurationOption(
                  label: 'Custom',
                  selected: customSelected,
                  fullWidth: true,
                  onTap: () => setState(() {
                        customSelected = true;
                        previewState = PreferencesPreviewState.customValid;
                        if (customController.text.isEmpty)
                          customController.text = '35';
                      }))),
        ]);
      });

  String? get _errorText => switch (previewState) {
        PreferencesPreviewState.customEmpty =>
          'Enter a duration from 1 to 1,440 minutes.',
        PreferencesPreviewState.invalidIncrement =>
          'Choose a duration in 5-minute increments.',
        PreferencesPreviewState.invalidRange =>
          'Enter a whole number from 1 to 1,440 minutes.',
        _ => null,
      };
}
