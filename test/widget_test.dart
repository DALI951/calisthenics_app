import 'package:calisthenics_app/app/app.dart';
import 'package:calisthenics_app/core/constants/app_ids.dart';
import 'package:calisthenics_app/features/auth/data/auth_providers.dart';
import 'package:calisthenics_app/features/auth/data/fake_auth_repository.dart';
import 'package:calisthenics_app/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-app smoke tests on an emulator-free backend:
/// auth flow via FakeAuthRepository + real router/theme/onboarding wiring.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppIds.prefOnboardingCompleted: true, // skip onboarding in these tests
    });
  });

  Widget buildApp(FakeAuthRepository repo) {
    return ProviderScope(
      overrides: [
        // Backend stays "unavailable" so nothing touches Firebase.
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const CalisthenicsApp(),
    );
  }

  testWidgets('fresh install lands on the sign-in screen', (tester) async {
    await tester.pumpWidget(buildApp(FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('signing in with a seeded account reaches the tab shell', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..seedAccount('dali@test.com', 'secret123');

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dali@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Tab shell is visible with today's plan. The primary button label
    // depends on the day type: training day → start, rest day → recovery.
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Workouts'), findsWidgets);
    final hasPrimaryAction =
        find.text('Start today\'s workout').evaluate().isNotEmpty ||
        find.text('See today\'s recovery').evaluate().isNotEmpty ||
        find.text('Resume workout').evaluate().isNotEmpty;
    expect(
      hasPrimaryAction,
      isTrue,
      reason: 'home should show the primary action',
    );
  });

  testWidgets('signing in with a wrong password shows a safe error', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..seedAccount('dali@test.com', 'secret123');

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dali@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Incorrect password. Try again or reset it.'),
      findsOneWidget,
    );
    // Still on the sign-in screen.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('google sign-in reaches the tab shell', (tester) async {
    final repo = FakeAuthRepository();

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Fake repository signs in a Google-style user → shell appears.
    expect(find.text('Calisthenics'), findsOneWidget);
  });

  testWidgets('signing out returns to the sign-in screen', (tester) async {
    final repo = FakeAuthRepository()
      ..seedAccount('dali@test.com', 'secret123');

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dali@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Profile via avatar in the app bar.
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('dali@test.com'), findsOneWidget);

    // "Sign out" sits below the fold — scroll the profile list until visible.
    final profileScrollable = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      100,
      scrollable: profileScrollable,
    );
    // scrollUntilVisible stops at "partly visible", which still leaves the
    // tap outside the test viewport — bring it fully on screen.
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('onboarding wizard completes the full flow into the shell', (
    tester,
  ) async {
    // Fresh install: onboarding NOT completed.
    SharedPreferences.setMockInitialValues({});

    final repo = FakeAuthRepository()
      ..seedAccount('dali@test.com', 'secret123');

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Sign in lands on the first onboarding step.
    await tester.enterText(find.byType(TextFormField).at(0), 'dali@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Experience level'), findsOneWidget);

    // Step 1: pick "Never trained".
    await tester.tap(find.text('Never trained'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: days — default selection kept, continue.
    expect(find.text('Preferred training days'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3: equipment — select pull-up bar.
    expect(find.text('Equipment at home'), findsOneWidget);
    await tester.tap(find.text('Pull-up bar'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 4: goals — one is preselected (consistency); continue.
    expect(find.text('Your goals'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 5: partner & setup — check the safety acknowledgement.
    expect(find.text('Partner & setup'), findsOneWidget);
    await tester.ensureVisible(find.text('Safety acknowledgement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety acknowledgement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 6: recap → start.
    expect(find.text('Your plan is ready'), findsOneWidget);
    await tester.tap(find.text('Start training'));
    await tester.pumpAndSettle();

    // Landed in the shell.
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Workouts'), findsWidgets);
  });
}
