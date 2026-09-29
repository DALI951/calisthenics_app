import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/data/auth_providers.dart';
import '../../presence/data/presence_providers.dart';
import '../../presence/domain/training_presence.dart';
import '../data/friends_providers.dart';
import '../domain/friend_models.dart';
import 'add_friend_sheet.dart';

/// Friends tab (spec §20–21): live friends + friend requests + search.
/// Presence (who's training now) lands in Phase 7.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    final friends = ref.watch(friendsListProvider).value ?? const [];
    final incoming =
        ref.watch(incomingFriendRequestsProvider).value ?? const [];
    final outgoing =
        ref.watch(outgoingFriendRequestsProvider).value ?? const [];
    final trainingNow =
        ref.watch(friendsPresenceProvider).value ?? const <TrainingPresence>[];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: ShellAppBar(
          title: 'Friends',
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Friends'),
              Tab(
                text: incoming.isEmpty
                    ? 'Requests'
                    : 'Requests (${incoming.length})',
              ),
            ],
          ),
        ),
        floatingActionButton: signedIn
            ? FloatingActionButton.extended(
                onPressed: () => showAddFriendSheet(context, ref),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add friend'),
              )
            : null,
        body: !signedIn
            ? const AppEmptyState(
                title: 'Sign in to connect',
                message:
                    'Friends need an account — go to Sign in from the '
                    'profile tab.',
                icon: Icons.lock_outline,
              )
            : TabBarView(
                children: [
                  // ---- Friends list -----------------------------------------
                  friends.isEmpty
                      ? AppEmptyState(
                          title: 'No friends yet',
                          message: outgoing.isEmpty
                              ? 'Tap "Add friend" and search a handle to '
                                    'start training together.'
                              : 'Waiting for ${outgoing.length} '
                                    'request${outgoing.length == 1 ? '' : 's'} '
                                    'to be accepted.',
                          icon: Icons.people_outline,
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          children: [
                            // Live presence strip (spec §22).
                            if (trainingNow.isNotEmpty) ...[
                              _TrainingNowStrip(trainingNow: trainingNow),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            for (final f in friends)
                              ListTile(
                                leading: _Avatar(
                                  handle: f.handle,
                                  photoUrl: f.photoUrl,
                                ),
                                title: Text(
                                  f.displayLabel,
                                  style: AppTypography.body,
                                ),
                                subtitle: Text(
                                  '@${f.handle}',
                                  style: AppTypography.caption.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                trailing: _MenuButton(
                                  onRemove: () =>
                                      confirmRemoveFriend(context, ref, f),
                                ),
                              ),
                          ],
                        ),

                  // ---- Requests tab ----------------------------------------
                  incoming.isEmpty
                      ? const AppEmptyState(
                          title: 'No requests',
                          message:
                              'When a training partner adds you by '
                              'handle, the request appears here.',
                          icon: Icons.mark_email_read_outlined,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          itemCount: incoming.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, i) {
                            final r = incoming[i];
                            return AppCard(
                              child: Row(
                                children: [
                                  _Avatar(handle: r.fromHandle),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.fromLabel,
                                          style: AppTypography.body,
                                        ),
                                        Text(
                                          '@${r.fromHandle}',
                                          style: AppTypography.caption.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Accept',
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(friendsRepositoryProvider)
                                          .acceptRequest(r);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Decline',
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: AppColors.textDisabled,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(friendsRepositoryProvider)
                                          .declineRequest(r);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}

class _TrainingNowStrip extends StatelessWidget {
  const _TrainingNowStrip({required this.trainingNow});

  final List<TrainingPresence> trainingNow;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulsingDot(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Training now (${trainingNow.length})',
                style: AppTypography.title,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final p in trainingNow)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  _Avatar(handle: p.handle),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${p.handle}', style: AppTypography.bodySmall),
                        Text(
                          p.exerciseName.isEmpty
                              ? p.dayName
                              : '${p.exerciseName} — ${p.dayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _elapsedLabel(p.elapsed),
                    style: AppTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _elapsedLabel(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes.clamp(1, 59)}m';
  }
}

/// Soft pulsing red dot (reassuring, not alarming — no shame, spec §27).
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentLight.withValues(alpha: 0.4 + _c.value * 0.6),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.handle, this.photoUrl});

  final String handle;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final letter = handle.isEmpty ? '?' : handle[0].toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.accentGlow,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? Text(
              letter,
              style: AppTypography.label.copyWith(color: AppColors.accentLight),
            )
          : null,
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: secondary, size: 20),
      color: AppColors.surfaceRaised,
      onSelected: (v) {
        if (v == 'remove') onRemove();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              const Icon(Icons.person_remove_outlined, size: 18),
              const SizedBox(width: AppSpacing.sm),
              const Text('Remove friend'),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> confirmRemoveFriend(
  BuildContext context,
  WidgetRef ref,
  FriendProfile f,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove friend?'),
      content: Text(
        '${f.displayLabel} (@${f.handle}) will disappear from your list. '
        'They can still send you a new request later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Remove',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(friendsRepositoryProvider).removeFriend(f.uid);
  }
}
