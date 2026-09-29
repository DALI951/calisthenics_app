import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../data/friends_providers.dart';
import '../domain/friend_models.dart';

/// Bottom sheet for adding a friend by handle (spec §20: add/search by
/// username). Shows live request state per result.
Future<void> showAddFriendSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _AddFriendSheet(),
  );
}

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results =
        ref.watch(userSearchProvider(_query)).value ?? const <UserProfile>[];
    final outgoing =
        ref.watch(outgoingFriendRequestsProvider).value ?? const [];
    final outgoingTargets = {for (final r in outgoing) r.toUid};

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a friend', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Search handle… e.g. dali951',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_query.length < 2)
            const AppEmptyState(
              title: 'Type at least 2 characters',
              message: 'Search by handle (the @name on a profile).',
              icon: Icons.manage_search,
            )
          else if (results.isEmpty)
            const AppEmptyState(
              title: 'No users found',
              message: 'Check the handle spelling — handles are unique.',
              icon: Icons.search_off,
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (ctx, i) {
                  final u = results[i];
                  final requested = outgoingTargets.contains(u.uid);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentGlow,
                      child: Text(
                        u.handle[0].toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentLight,
                        ),
                      ),
                    ),
                    title: Text(u.displayLabel, style: AppTypography.body),
                    subtitle: Text(
                      '@${u.handle}',
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: requested
                        ? const Text(
                            'Requested',
                            style: TextStyle(color: AppColors.textDisabled),
                          )
                        : SizedBox(
                            height: 36,
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentGlow,
                                foregroundColor: AppColors.accentLight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                              ),
                              onPressed: () async {
                                final repo = ref.read(
                                  friendsRepositoryProvider,
                                );
                                final messenger = ScaffoldMessenger.of(ctx);
                                try {
                                  await repo.sendRequest(u.handle);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Request sent to @${u.handle}',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } on Exception catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
