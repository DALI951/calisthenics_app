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

    // Tab shell is visible with today's plan.
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Workouts'), findsWidgets);
    expect(find.text('Open today\'s plan'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(InkWell, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
