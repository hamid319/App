import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../common/models/group_model.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';
import 'trip_ui.dart';

/// Opens the share sheet with an invitation: the web link (friends join in
/// the browser, no app needed) and the code for people with the app.
Future<void> copyTripInvite(BuildContext context, GroupModel group) async {
  final l10n = context.l10n;
  final code = group.invite?.code;
  if (code == null || code.isEmpty) {
    showTripSnack(context, l10n.joiningDisabled);
    return;
  }
  final link = '${AppConfig.inviteBaseUrl}/$code';
  // iPad needs an anchor for the share popover.
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    text: l10n.tripInviteMessage(
        group.groupName ?? l10n.unnamedGroup, code, link),
    subject: group.groupName ?? l10n.unnamedGroup,
    sharePositionOrigin:
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}

/// Members of a trip with the invite code; leave or (owner) delete it.
Future<void> showTripMembersSheet(
    BuildContext context, GroupModel group, String userId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MembersSheet(group: group, userId: userId),
  );
}

class _MembersSheet extends ConsumerWidget {
  const _MembersSheet({required this.group, required this.userId});

  final GroupModel group;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isOwner = group.ownerUid == userId;
    final showInvite = group.invite != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.membersHeader(group.members.length),
              style: text.headlineSmall),
          const SizedBox(height: 16),
          if (showInvite)
            TripCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.inviteCodeTitle,
                            style: text.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        Text(group.invite!.code,
                            style: text.headlineSmall
                                ?.copyWith(letterSpacing: 4)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => copyTripInvite(context, group),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l10n.tripInvite),
                  ),
                ],
              ),
            )
          else
            Text(l10n.joiningDisabled,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          InsetGroup(
            separatorIndent: 14 + 40 + 12,
            children: [
              for (final (i, uid) in group.members.indexed)
                _MemberRow(
                  memberId: uid,
                  fallbackName: l10n.memberFallback(i + 1),
                  isMe: uid == userId,
                  isAdmin: uid == group.ownerUid,
                ),
            ],
          ),
          const SizedBox(height: 24),
          InsetGroup(
            children: [
              ListTile(
                leading: Icon(Icons.logout_rounded, color: scheme.error),
                title: Text(l10n.tripLeave,
                    style: TextStyle(color: scheme.error)),
                onTap: () => _leave(context, ref),
              ),
              if (isOwner)
                ListTile(
                  leading:
                      Icon(Icons.delete_outline_rounded, color: scheme.error),
                  title: Text(l10n.tripDelete,
                      style: TextStyle(color: scheme.error)),
                  onTap: () => _delete(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await _confirm(
        context, l10n.leaveGroupTitle, l10n.leaveGroupBody, l10n.leave);
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(groupControllerProvider.notifier)
        .leaveGroup(group.groupId, userId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.leftGroup)));
    router.go('/trips');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await _confirm(
      context,
      l10n.deleteGroupTitle,
      l10n.deleteGroupBody(group.groupName ?? l10n.unnamedGroup),
      l10n.delete,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupRepositoryProvider).deleteGroup(group.groupId);
      ref.read(selectedGroupIdProvider.notifier).updateState(null);
      router.go('/trips');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content:
            Text(userMessage(e, fallback: l10n.errorDeleteGroup, l10n: l10n)),
      ));
    }
  }
}

Future<bool> _confirm(
    BuildContext context, String title, String body, String action) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
}

/// One member: avatar, friendly name (never an email), admin note.
class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.memberId,
    required this.fallbackName,
    required this.isMe,
    required this.isAdmin,
  });

  final String memberId;
  final String fallbackName;
  final bool isMe;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = memberName(ref, memberId, fallbackName);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          MemberAvatar(id: memberId, name: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? l10n.memberYou(name) : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
          ),
          if (isAdmin)
            Text(l10n.admin,
                style:
                    text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
