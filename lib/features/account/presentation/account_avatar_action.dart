import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

enum AccountPreviewState {
  normal,
  noDisplayName,
  focused,
  validationError,
  saving,
  saveError,
  signOutError
}

class AccountAvatarAction extends StatefulWidget {
  const AccountAvatarAction({required this.onSignOut, super.key});
  final VoidCallback onSignOut;

  @override
  State<AccountAvatarAction> createState() => _AccountAvatarActionState();
}

class _AccountAvatarActionState extends State<AccountAvatarAction> {
  static const displayName = 'Alex Kumar';
  static const email = 'alex@example.com';
  AccountPreviewState previewState = AccountPreviewState.normal;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_AccountAction>(
        tooltip: 'Account options',
        offset: const Offset(0, 8),
        color: DayweaveColors.card,
        shape: const RoundedRectangleBorder(borderRadius: DayweaveRadii.md),
        onSelected: (action) {
          switch (action) {
            case _AccountAction.edit:
              _openProfile(context);
            case _AccountAction.signOut:
              if (previewState == AccountPreviewState.signOutError) {
                _openMenuError(context);
              } else {
                widget.onSignOut();
              }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<_AccountAction>(
              enabled: false, child: _identity(context)),
          const PopupMenuDivider(),
          const PopupMenuItem(
              value: _AccountAction.edit,
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit profile'))),
          const PopupMenuItem(
              value: _AccountAction.signOut,
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'))),
        ],
        child: GestureDetector(
          onLongPress: () => _choosePreview(context),
          child: const Padding(
              padding: EdgeInsets.all(6),
              child: CircleAvatar(
                  radius: 17,
                  backgroundColor: DayweaveColors.ink,
                  child: Text('AK',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)))),
        ),
      );

  Widget _identity(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            previewState == AccountPreviewState.noDisplayName
                ? email
                : displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 18),
        const Row(children: [
          Icon(Icons.circle, size: 9, color: Colors.green),
          SizedBox(width: 8),
          Text('Signed in')
        ]),
        if (previewState == AccountPreviewState.signOutError) ...[
          const SizedBox(height: 10),
          const Text('Unable to sign out.\nPlease try again.',
              style: TextStyle(color: DayweaveColors.coral, fontSize: 12)),
        ],
      ]);

  Future<void> _choosePreview(BuildContext context) async {
    final state = await showDialog<AccountPreviewState>(
        context: context,
        builder: (context) => SimpleDialog(
            title: const Text('Preview profile UI'),
            children: AccountPreviewState.values
                .map((state) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, state),
                    child: Text(_label(state))))
                .toList()));
    if (!mounted || state == null) return;
    setState(() => previewState = state);
    if (state == AccountPreviewState.signOutError) return;
    if (state != AccountPreviewState.normal &&
        state != AccountPreviewState.signOutError) _openProfile(context);
  }

  void _openProfile(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => EditProfileDialog(previewState: previewState));

  void _openMenuError(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
              title: const Text('Sign out'),
              content: const Text('Unable to sign out.\nPlease try again.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ]));

  String _label(AccountPreviewState state) => switch (state) {
        AccountPreviewState.normal => 'Normal / menu open',
        AccountPreviewState.noDisplayName => 'No display name',
        AccountPreviewState.focused => 'Focused input',
        AccountPreviewState.validationError => 'Validation error',
        AccountPreviewState.saving => 'Saving',
        AccountPreviewState.saveError => 'Save failure',
        AccountPreviewState.signOutError => 'Sign-out failure'
      };
}

enum _AccountAction { edit, signOut }

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({required this.previewState, super.key});
  final AccountPreviewState previewState;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController controller = TextEditingController(
      text: widget.previewState == AccountPreviewState.noDisplayName ||
              widget.previewState == AccountPreviewState.validationError
          ? ''
          : 'Alex Kumar');
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.previewState == AccountPreviewState.focused)
      WidgetsBinding.instance
          .addPostFrameCallback((_) => focusNode.requestFocus());
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: DayweaveColors.card,
        shape: const RoundedRectangleBorder(borderRadius: DayweaveRadii.lg),
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Keep the name you want Dayweave to use for you.'),
          const SizedBox(height: 20),
          const Text('Display name',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.previewState != AccountPreviewState.saving,
              decoration: InputDecoration(
                  errorText:
                      widget.previewState == AccountPreviewState.validationError
                          ? 'Enter a display name.'
                          : null)),
          if (widget.previewState == AccountPreviewState.saveError) ...[
            const SizedBox(height: 8),
            const Text('Unable to save your profile. Please try again.',
                softWrap: true,
                style: TextStyle(color: DayweaveColors.coral, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          const TextField(
              enabled: false,
              decoration: InputDecoration(hintText: 'alex@example.com')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: widget.previewState == AccountPreviewState.saving
                  ? null
                  : () {},
              child: Text(widget.previewState == AccountPreviewState.saving
                  ? 'Saving...'
                  : 'Save')),
        ],
      );
}
