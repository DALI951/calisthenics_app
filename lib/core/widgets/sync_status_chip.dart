import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_status.dart';

/// The honest sync indicator (spec §31): Synced / Pending sync / Sync failed.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(syncStatusProvider).value ?? const SyncStatus.synced();
    final (color, icon) = switch (status.phase) {
      SyncPhase.synced => (AppColors.success, Icons.cloud_done_outlined),
      SyncPhase.pending => (AppColors.warning, Icons.cloud_upload_outlined),
      SyncPhase.failed => (AppColors.danger, Icons.cloud_off_outlined),
    };
    return Tooltip(
      message: status.phase == SyncPhase.failed
          ? (status.lastError ?? 'Could not reach the server')
          : 'Your workouts are saved on this phone and sync automatically.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
