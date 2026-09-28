import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import 'onboarding_providers.dart';

/// Phase 1 welcome step. The full multi-step onboarding (experience level,
/// training days, equipment, goals, partner, units, notifications) builds
/// on this exact shell in Phase 2 — same screen, more steps.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _completing = false;

  Future<void> _finish() async {
    setState(() => _completing = true);
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (mounted) setState(() => _completing = false);
    // Router redirect moves to /app/home.
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppColors.onAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Train. Record. Recover. Improve.',
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Welcome to Calisthenics — a 4-day beginner program '
                    'built around you and one training partner.\n\n'
                    'In the next step we\'ll ask about your experience, '
                    'equipment and goals so your plan fits you.',
                    style: AppTypography.body.apply(color: secondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppPrimaryButton(
                    label: 'Get started',
                    icon: Icons.arrow_forward,
                    loading: _completing,
                    onPressed: _completing ? null : _finish,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Full onboarding (experience, equipment, goals, partner) '
                    'arrives in the next build phase.',
                    style: AppTypography.caption.apply(color: secondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
