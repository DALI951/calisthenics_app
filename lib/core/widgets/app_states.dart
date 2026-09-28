import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// Skeleton loading state — never a blank screen.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.height = 88,
    this.width = double.infinity,
    this.lines = 1,
  });

  final double height;
  final double width;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ],
      ],
    );
  }
}

/// Standard loading body: branded spinner + label.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.apply(color: secondary),
          ),
        ],
      ),
    );
  }
}
