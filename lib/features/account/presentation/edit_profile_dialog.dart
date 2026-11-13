import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../../services/providers.dart';
import '../../auth/application/current_user_provider.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({required this.user, super.key});

  final User user;

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: _initialDisplayName(widget.user));
  late final TextEditingController _emailController =
      TextEditingController(text: widget.user.email?.trim() ?? '');
  late final FocusNode _nameFocusNode = FocusNode();
  bool _saving = false;
  String? _error;

  String get _userId => widget.user.id;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser?.id != _userId) {
      setState(() => _error = 'Your account changed. Please try again.');
      return;
    }

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _error = 'Enter a display name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).updateDisplayName(trimmedName);
      if (!mounted) return;
      if (ref.read(currentUserProvider)?.id != _userId) {
        setState(() {
          _saving = false;
          _error = 'Your account changed. Please try again.';
        });
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null || currentUser.id != _userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keep the name you want Dayweave to use for you.'),
            const SizedBox(height: 20),
            const Text('Display name'),
            const SizedBox(height: 7),
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                errorText: _error == 'Enter a display name.' ? _error : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Email'),
            const SizedBox(height: 7),
            TextField(
              controller: _emailController,
              enabled: false,
            ),
            if (_error != null && _error != 'Enter a display name.') ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: DayweaveColors.coral),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

String _initialDisplayName(User user) {
  final value = user.userMetadata?['display_name'];
  if (value is! String) return '';
  final trimmed = value.trim();
  return trimmed;
}
