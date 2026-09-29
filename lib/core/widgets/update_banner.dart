import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../update/update_providers.dart';

/// A quiet, non-nagging update surface: only ever shows up when there is
/// genuinely something new. No nagging loops, no "update!" banners for a patch
/// you are already on.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);

    if (state is UpdateDownloading) {
      return _Bar(
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: state.progress <= 0 ? null : state.progress,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(state.progress * 100).round()}%',
              style: AppTypography.caption,
            ),
          ],
        ),
      );
    }

    if (state is UpdateReadyToInstall) {
      // The APK is downloaded; the phone still has to allow the install. Name
      // that permission up front, because "it did nothing" is the usual
      // failure and the setting lives somewhere nobody thinks to look.
      return _Bar(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update downloaded. Tap Install, then allow "Install unknown apps"'
              ' for Calisthenics if your phone asks.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                FilledButton(
                  onPressed: () =>
                      ref.read(updateControllerProvider.notifier).install(),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Install update'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      ref.read(updateControllerProvider.notifier).reset(),
                  child: const Text('Later'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (state is UpdateFailed) {
      return _Bar(
        child: Row(
          children: [
            Expanded(child: Text(state.message, style: AppTypography.caption)),
            TextButton(
              onPressed: () =>
                  ref.read(updateControllerProvider.notifier).check(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is UpdateDone && state.hasUpdate) {
      final release = state.decision.release!;
      final apk = release.hasApk;
      return _Bar(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${release.tag} is available.',
                style: AppTypography.caption,
              ),
            ),
            TextButton(
              onPressed: apk
                  ? () => ref.read(updateControllerProvider.notifier).download()
                  : null,
              child: Text(apk ? 'Download' : 'See release'),
            ),
            if (apk)
              TextButton(
                onPressed: () =>
                    ref.read(updateControllerProvider.notifier).reset(),
                child: const Text('Later'),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
