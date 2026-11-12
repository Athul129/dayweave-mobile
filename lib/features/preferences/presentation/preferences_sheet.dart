import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../application/preferences_controller.dart';
import '../application/preferences_state.dart';
import 'preference_duration_option.dart';

Future<void> showPreferencesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PreferencesSheet(),
    );

class PreferencesSheet extends ConsumerStatefulWidget {
  const PreferencesSheet({super.key});

  @override
  ConsumerState<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends ConsumerState<PreferencesSheet> {
  static const _presets = <int>[15, 30, 45, 60];

  late final TextEditingController customController = TextEditingController();
  final customFocusNode = FocusNode();
  final customFieldKey = GlobalKey();
  String? _inputError;
  bool _customMode = false;
  bool _pendingPresetSave = false;

  @override
  void initState() {
    super.initState();
    customFocusNode.addListener(_keepCustomFieldVisible);
  }

  @override
  void dispose() {
    customFocusNode.removeListener(_keepCustomFieldVisible);
    customController.dispose();
    customFocusNode.dispose();
    super.dispose();
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
  Widget build(BuildContext context) => _content(context);

  Widget _content(BuildContext context) {
    final preferences = ref.watch(preferencesProvider);
    final savedMinutes = preferences.defaultTaskMinutes;
    final savedCustom = !_presets.contains(savedMinutes);

    if (savedCustom && !_pendingPresetSave) _customMode = true;
    if (!savedCustom && _pendingPresetSave) {
      _pendingPresetSave = false;
      _customMode = false;
    }
    if (!_customMode && !customFocusNode.hasFocus && !preferences.isSaving) {
      if (customController.text.isNotEmpty) customController.clear();
    } else if (_customMode &&
        !customFocusNode.hasFocus &&
        !preferences.isSaving &&
        customController.text.isEmpty) {
      customController.text = savedMinutes.toString();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: DayweaveColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.xl,
            12,
            DayweaveSpacing.xl,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DayweaveColors.line,
                    borderRadius: DayweaveRadii.sm,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Preferences',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontFamily: 'Fraunces', fontSize: 26),
              ),
              const SizedBox(height: 7),
              Text(
                'Choose the starting length for new tasks.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              Text(
                'Default task duration',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 10),
              if (preferences.isLoading)
                const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
              _options(preferences),
              if (_customMode) _customInput(preferences),
              if (preferences.errorKind == PreferencesErrorKind.load) ...[
                const SizedBox(height: 8),
                const Text(
                  'Could not load saved preferences. Using the default.',
                  style: TextStyle(color: DayweaveColors.coral),
                ),
                TextButton(
                  onPressed: preferences.isLoading ? null : _retryLoad,
                  child: const Text('Retry'),
                ),
              ],
              if (preferences.errorKind == PreferencesErrorKind.save) ...[
                const SizedBox(height: 8),
                const Text(
                  'Could not save this preference. Please try again.',
                  style: TextStyle(color: DayweaveColors.coral),
                ),
                TextButton(
                  onPressed: preferences.isSaving ? null : _retry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _customInput(PreferencesState preferences) => Container(
        key: customFieldKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Custom minutes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: customController,
              focusNode: customFocusNode,
              keyboardType: TextInputType.number,
              enabled: !preferences.isLoading && !preferences.isSaving,
              onChanged: _onCustomChanged,
              onSubmitted: (_) => _saveCustom(),
              decoration: InputDecoration(
                hintText: '35',
                errorText: _inputError,
                suffixIcon: const Icon(Icons.unfold_more, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _options(PreferencesState preferences) => LayoutBuilder(
        builder: (context, constraints) {
          final disabled = preferences.isLoading || preferences.isSaving;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presets.map(
                (minutes) => SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: PreferenceDurationOption(
                    label: '$minutes minutes',
                    selected: !_customMode &&
                        preferences.defaultTaskMinutes == minutes,
                    onTap: disabled ? null : () => _save(minutes),
                  ),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: PreferenceDurationOption(
                  label: 'Custom',
                  selected: _customMode,
                  fullWidth: true,
                  onTap: disabled
                      ? null
                      : () {
                          setState(() {
                            _customMode = true;
                            _inputError = null;
                            if (customController.text.isEmpty) {
                              customController.text =
                                  preferences.defaultTaskMinutes.toString();
                            }
                          });
                          customFocusNode.requestFocus();
                        },
                ),
              ),
            ],
          );
        },
      );

  void _onCustomChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _inputError = 'Enter a duration from 1 to 1,440 minutes.');
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      setState(() => _inputError = 'Enter a whole number.');
      return;
    }
    if (parsed < 1 || parsed > 1440) {
      setState(() => _inputError = 'Enter a duration from 1 to 1,440 minutes.');
      return;
    }
    if (parsed % 5 != 0) {
      setState(() => _inputError = 'Choose a duration in 5-minute increments.');
      return;
    }
    setState(() => _inputError = null);
    unawaited(_save(parsed));
  }

  Future<void> _saveCustom() async {
    final parsed = int.tryParse(customController.text.trim());
    if (parsed == null || !isValidDefaultTaskMinutes(parsed)) {
      _onCustomChanged(customController.text);
      return;
    }
    await _save(parsed);
  }

  Future<void> _save(int value) async {
    if (!mounted) return;
    setState(() {
      _inputError = null;
      if (_presets.contains(value)) {
        _pendingPresetSave = true;
        _customMode = false;
      }
    });
    await ref.read(preferencesProvider.notifier).save(value);
  }

  Future<void> _retry() async {
    final preferences = ref.read(preferencesProvider);
    await _save(preferences.defaultTaskMinutes);
  }

  Future<void> _retryLoad() => ref.read(preferencesProvider.notifier).load();
}
