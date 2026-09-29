import 'dart:convert';

import 'package:calisthenics_app/features/onboarding/domain/onboarding_answers.dart';
import 'package:calisthenics_app/features/onboarding/presentation/onboarding_providers.dart';
import 'package:calisthenics_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:calisthenics_app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression cover for "it keeps throwing me back to the experience level
/// page".
///
/// The wizard used to keep its step and its answers in widget state only, so
/// ANY rebuild of the screen silently restarted setup at step 0 and threw
/// away every answer. Now the resume point is on disk, so a remount, a router
/// refresh, or the app being killed all resume in place.
void main() {
  const stepKey = 'calisthenics.onboarding.step.v1';
  const draftKey = 'calisthenics.onboarding.draft.v1';

  Widget harness() =>
      ProviderScope(child: const MaterialApp(home: OnboardingScreen()));

  testWidgets('progress survives the screen being rebuilt from scratch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Experience level'), findsOneWidget);
    await tester.tap(find.text('Some experience').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Preferred training days'), findsOneWidget);

    // Something rebuilds/remounts the wizard (router refresh, hot restart...).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.text('Experience level'),
      findsNothing,
      reason: 'must NOT be thrown back to the first step',
    );
    expect(find.text('Preferred training days'), findsOneWidget);
  });

  testWidgets('the chosen answers are restored, not just the step', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Some experience').first);
    await tester.pumpAndSettle();
    // Advance so there IS a step worth resuming.
    await tester.tap(find.widgetWithText(AppPrimaryButton, 'Continue'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    expect(raw, isNotNull, reason: 'the draft must be written to disk');
    expect(
      prefs.getInt(stepKey),
      1,
      reason: 'the step must be written to disk',
    );
    final saved = OnboardingAnswers.fromJson(
      (jsonDecode(raw!) as Map).cast<String, Object?>(),
    );
    expect(saved.experienceLevel, ExperienceLevel.some);

    // Remount and confirm we resume at step 1, with the answer still selected.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Preferred training days'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppSecondaryButton, 'Back'));
    await tester.pumpAndSettle();
    // We are back on step 0 and the answer survived the round trip.
    expect(find.text('Experience level'), findsOneWidget);
    final continueButton = tester.widget<AppPrimaryButton>(
      find.widgetWithText(AppPrimaryButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('a stale out-of-range step is clamped, not crashed on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({stepKey: 99});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your plan is ready'), findsOneWidget);
  });

  testWidgets('a corrupt draft never blocks setup', (tester) async {
    SharedPreferences.setMockInitialValues({draftKey: 'not json {{{'});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Experience level'), findsOneWidget);
  });

  testWidgets('step 0 offers an explicit sign out instead of a dead pop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppSecondaryButton, 'Sign out'), findsOneWidget);
    expect(find.widgetWithText(AppSecondaryButton, 'Cancel'), findsNothing);
  });

  test('the resume point is cleared once setup finishes', () async {
    SharedPreferences.setMockInitialValues({stepKey: 3, draftKey: '{}'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(onboardingDraftProvider.notifier).clearDraft();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(draftKey), isNull);
  });
}
