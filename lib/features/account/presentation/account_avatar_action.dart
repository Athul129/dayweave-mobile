import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../auth/application/current_user_provider.dart';
import 'edit_profile_dialog.dart';

class AccountAvatarAction extends ConsumerWidget {
  const AccountAvatarAction({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final email = user.email?.trim() ?? '';
    final displayName = _displayName(user) ?? email;
    final initialsSource = _displayName(user) ?? email.split('@').first;
    final initials = accountInitials(initialsSource);

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account options',
      offset: const Offset(0, 8),
      color: DayweaveColors.card,
      shape: const RoundedRectangleBorder(borderRadius: DayweaveRadii.md),
      onSelected: (action) {
        switch (action) {
          case _AccountAction.editProfile:
            showDialog<void>(
              context: context,
              builder: (_) => EditProfileDialog(user: user),
            );
          case _AccountAction.signOut:
            onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: _identity(context, displayName, email),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_AccountAction>(
          value: _AccountAction.editProfile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit profile'),
          ),
        ),
        const PopupMenuItem<_AccountAction>(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: DayweaveColors.ink,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, String displayName, String email) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 18),
          const Row(
            children: [
              Icon(Icons.circle, size: 9, color: Colors.green),
              SizedBox(width: 8),
              Text('Signed in'),
            ],
          ),
        ],
      );

  static String? _displayName(User user) {
    final value = user.userMetadata?['display_name'];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

enum _AccountAction { editProfile, signOut }

String accountInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'[\s._+\-]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return String.fromCharCodes(parts.first.runes.take(2)).toUpperCase();
  }
  return '${String.fromCharCode(parts.first.runes.first)}'
          '${String.fromCharCode(parts[1].runes.first)}'
      .toUpperCase();
}
