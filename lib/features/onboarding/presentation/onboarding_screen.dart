import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_ids.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../../exercises/domain/exercise_enums.dart';
import '../domain/onboarding_answers.dart';
import 'onboarding_providers.dart';

/// Full multi-step onboarding (spec §8): experience, training days,
/// equipment, goals, partner + safety + units + notifications, recap.
///
/// The 4-day program cycle is fixed — the answers shape how it adapts:
/// equipment-aware substitutions, safe starting progressions, reminders.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _completing = false;
  bool _restored = false;

  static const _titles = [
    'Experience level',
    'Preferred training days',
    'Equipment at home',
    'Your goals',
    'Partner & setup',
    'Your plan is ready',
  ];

  static const _stepKey = '${AppIds.prefPrefix}onboarding.step.v1';

  @override
  void initState() {
    super.initState();
    // Resume where this person left off. Anything that rebuilds this screen
    // now keeps the wizard exactly where it was, answers included.
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    await ref.read(onboardingDraftProvider.notifier).restoreFromDisk();
    final savedStep = prefs.getInt(_stepKey);
    if (!mounted) return;
    setState(() {
      _step = (savedStep ?? 0).clamp(0, _titles.length - 1);
      _restored = true;
    });
  }

  void _persistStep() {
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_stepKey, _step))
        .ignore();
  }

  void _next() {
    if (_step < _titles.length - 1) {
      setState(() => _step++);
      _persistStep();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _persistStep();
    } else {
      // There is nowhere to go back to, and popping here used to bounce the
      // user into a brand-new wizard at step 0. Offer the one real exit.
      _confirmSignOut();
    }
  }

  Future<void> _confirmSignOut() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop setting up?'),
        content: const Text(
          'Your progress is saved, so you can pick this up later without '
          'starting over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep setting up'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await ref.read(onboardingControllerProvider.notifier).reset();
      await ref.read(onboardingDraftProvider.notifier).clearDraft();
      await SharedPreferences.getInstance().then((p) => p.remove(_stepKey));
      if (mounted) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
    }
  }

  Future<void> _finish() async {
    final answers = ref.read(onboardingDraftProvider);
    setState(() => _completing = true);
    await ref
        .read(onboardingControllerProvider.notifier)
        .complete(answers.copyWith(safetyAcknowledged: true));
    // The wizard is done — drop the resume point so a later "reset" really is
    // a clean start.
    await ref.read(onboardingDraftProvider.notifier).clearDraft();
    await SharedPreferences.getInstance().then((p) => p.remove(_stepKey));
    if (mounted) setState(() => _completing = false);
    // Router redirect moves to /app/home.
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingDraftProvider);
    final canContinue = _step == 3
        ? answers.goals.isNotEmpty
        : _step == 4
        ? answers.safetyAcknowledged
        : true;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step, total: _titles.length),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_titles[_step], style: AppTypography.headline),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _subtitle(_step),
                        style: AppTypography.body.apply(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ..._stepWidget(answers),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Row(
                  children: [
                    AppSecondaryButton(
                      label: _step == 0 ? 'Sign out' : 'Back',
                      onPressed: _completing || !_restored ? null : _back,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _step == _titles.length - 1
                          ? AppPrimaryButton(
                              label: 'Start training',
                              icon: Icons.play_arrow,
                              loading: _completing,
                              onPressed: _completing ? null : _finish,
                            )
                          : AppPrimaryButton(
                              label: 'Continue',
                              icon: Icons.arrow_forward,
                              onPressed: canContinue ? _next : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(int step) {
    switch (step) {
      case 0:
        return 'Your starting progressions adapt to how comfortable you '
            'already are. There are no wrong answers.';
      case 1:
        return 'Pick the days that realistically work for you. The 4-day '
            'program (Push, Pull, Legs, Full Body) keeps its cycle — this '
            'tunes reminders and gentle consistency nudges.';
      case 2:
        return 'We\'ll substitute movements your gear can\'t support '
            '(spec: never assume equipment exists).';
      case 3:
        return 'Select what matters most right now.';
      case 4:
        return 'One training partner makes this app a lot more fun — and '
            'a couple of quick setup choices.';
      default:
        return 'Everything below shapes your plan. Confirm and start.';
    }
  }

  List<Widget> _stepWidget(OnboardingAnswers answers) {
    switch (_step) {
      case 0:
        return _experienceStep(answers);
      case 1:
        return _daysStep(answers);
      case 2:
        return _equipmentStep(answers);
      case 3:
        return _goalsStep(answers);
      case 4:
        return _setupStep(answers);
      default:
        return _recapStep(answers);
    }
  }

  List<Widget> _experienceStep(OnboardingAnswers answers) {
    return ExperienceLevel.values
        .map(
          (lvl) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              highlight: answers.experienceLevel == lvl,
              onTap: () => ref
                  .read(onboardingDraftProvider.notifier)
                  .update((a) => a.copyWith(experienceLevel: lvl)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        lvl == ExperienceLevel.never
                            ? Icons.eco
                            : lvl == ExperienceLevel.some
                            ? Icons.trending_up
                            : Icons.rocket_launch,
                        size: 20,
                        color: answers.experienceLevel == lvl
                            ? AppColors.accentLight
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(lvl.label, style: AppTypography.title),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lvl.description,
                    style: AppTypography.bodySmall.apply(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _daysStep(OnboardingAnswers answers) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = answers.trainingDays.contains(day);
          return ChoiceChip(
            label: Text(names[i]),
            selected: selected,
            onSelected: (on) {
              ref.read(onboardingDraftProvider.notifier).update((a) {
                final days = {...a.trainingDays};
                on ? days.add(day) : days.remove(day);
                return a.copyWith(trainingDays: days);
              });
            },
          );
        }),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        answers.trainingDays.isEmpty
            ? 'Select at least one day to continue.'
            : 'Selected: ${answers.daysLabel}',
        style: AppTypography.bodySmall.apply(
          color: answers.trainingDays.isEmpty
              ? AppColors.danger
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  List<Widget> _equipmentStep(OnboardingAnswers answers) {
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: Equipment.values.map((e) {
          final selected = answers.equipment.contains(e);
          final isNone = e == Equipment.none;
          return FilterChip(
            label: Text(e.label),
            selected: selected,
            onSelected: (on) {
              ref.read(onboardingDraftProvider.notifier).update((a) {
                if (on && isNone) {
                  // Selecting "no equipment" clears everything else.
                  return a.copyWith(equipment: {Equipment.none});
                }
                final gear = {...a.equipment}..remove(Equipment.none);
                on ? gear.add(e) : gear.remove(e);
                return a.copyWith(
                  equipment: gear.isEmpty ? {Equipment.none} : gear,
                );
              });
            },
          );
        }).toList(),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        '${answers.equipmentLabel}. Pull-ups and dips will fall back to '
        'safe progressions when their gear is missing.',
        style: AppTypography.bodySmall.apply(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  List<Widget> _goalsStep(OnboardingAnswers answers) {
    return TrainingGoal.values
        .map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CheckboxListTile(
              value: answers.goals.contains(g),
              onChanged: (on) {
                ref.read(onboardingDraftProvider.notifier).update((a) {
                  final goals = {...a.goals};
                  on == true ? goals.add(g) : goals.remove(g);
                  return a.copyWith(goals: goals);
                });
              },
              title: Text(g.label, style: AppTypography.body),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        )
        .toList();
  }

  List<Widget> _setupStep(OnboardingAnswers answers) {
    return [
      AppCard(
        child: Column(
          children: [
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                value: answers.hasTrainingPartner,
                onChanged: (on) => ref
                    .read(onboardingDraftProvider.notifier)
                    .update((a) => a.copyWith(hasTrainingPartner: on)),
                title: const Text('I train with a partner'),
                subtitle: const Text(
                  'Enables friends, live training status and challenges.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                value: answers.notificationsEnabled,
                onChanged: (on) => ref
                    .read(onboardingDraftProvider.notifier)
                    .update((a) => a.copyWith(notificationsEnabled: on)),
                title: const Text('Workout reminders & rest timer'),
                subtitle: const Text('Gentle nudges only — never spam.'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Units', style: AppTypography.title),
      const SizedBox(height: AppSpacing.sm),
      SegmentedButton<UnitsPreference>(
        segments: UnitsPreference.values
            .map((u) => ButtonSegment(value: u, label: Text(u.label)))
            .toList(),
        selected: {answers.preferredUnits},
        onSelectionChanged: (s) => ref
            .read(onboardingDraftProvider.notifier)
            .update((a) => a.copyWith(preferredUnits: s.first)),
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        highlight: !answers.safetyAcknowledged,
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: answers.safetyAcknowledged,
            onChanged: (on) => ref
                .read(onboardingDraftProvider.notifier)
                .update((a) => a.copyWith(safetyAcknowledged: on == true)),
            title: const Text('Safety acknowledgement'),
            subtitle: const Text(
              'Before starting any new exercise program, check with a trusted '
              'adult or a doctor if you have any health concerns. Listen to '
              'your body: technique first, never train through sharp pain.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ),
    ];
  }

  List<Widget> _recapStep(OnboardingAnswers answers) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.bodySmall.apply(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.body)),
        ],
      ),
    );

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Experience', answers.experienceLabel),
            row('Days', answers.daysLabel),
            row('Equipment', answers.equipmentLabel),
            row('Goals', answers.goalsLabel),
            row(
              'Partner',
              answers.hasTrainingPartner
                  ? 'Yes — build the social loop'
                  : 'Solo mode',
            ),
            row('Units', answers.preferredUnits.label),
            row('Reminders', answers.notificationsEnabled ? 'On' : 'Off'),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Your 4-day program (Push + Core, Pull + Core, Legs + Core, '
        'Full Body) is prepared around these answers. You can change '
        'everything later in Settings.',
        style: AppTypography.bodySmall.apply(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 4,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step
                      ? AppColors.accent
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
