import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/onboarding/presentation/onboarding_providers.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/challenges/presentation/challenges_screen.dart';
import '../../features/exercises/presentation/exercise_detail_screen.dart';
import '../../features/exercises/presentation/exercise_search_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/progress/presentation/history_detail_screen.dart';
import '../../features/progress/presentation/history_screen.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/progression/presentation/maxes_screen.dart';
import '../../features/workout_session/presentation/rest_day_screen.dart';
import '../../features/workout_session/presentation/workout_session_screen.dart';
import '../../features/workout_session/presentation/workout_summary_screen.dart';
import '../../features/workouts/presentation/day_editor_screen.dart';
import '../../features/workouts/presentation/program_editor_screen.dart';
import '../../features/workouts/presentation/session_builder_screen.dart';
import '../../features/workouts/presentation/workouts_screen.dart';
import 'app_shell.dart';

/// Notifies go_router when auth/onboarding state changes so redirects
/// re-evaluate (go_router requires a Listenable for this).
class GoRouterNotifier extends ChangeNotifier {
  GoRouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
    _ref.listen(onboardingControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final user = _ref.read(authControllerProvider).value;
    final onboarding = _ref.read(onboardingControllerProvider);

    final path = state.matchedLocation;
    final onAuth = path.startsWith('/auth');

    // Signed out → everything redirects to /auth.
    if (user == null) {
      return onAuth ? null : '/auth';
    }

    // While the persisted flags are still loading we do NOT decide. Treating
    // "loading" as "not onboarded" used to kick a half-finished setup back to
    // the first onboarding step whenever the provider reloaded.
    if (onboarding.isLoading) return null;
    final onboardingDone = onboarding.value ?? false;

    // Signed in but never onboarded → onboarding.
    if (!onboardingDone) {
      return path == '/onboarding' ? null : '/onboarding';
    }

    // Signed in + onboarded → keep signed-in users off auth/onboarding.
    if (onAuth || path == '/onboarding') {
      return '/app/home';
    }

    return null;
  }
}

/// The app router (go_router 18). Route map:
///   /auth            sign in
///   /auth/sign-up    create account
///   /auth/forgot     reset password
///   /onboarding      first-run onboarding
///   /app/*           5-tab shell (home, workouts, progress, challenges, friends)
///   /profile         profile + settings (outside the main tabs)
Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  // Root navigator: session/summary push OVER the shell (no tabs mid-set).
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: '/app/home',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    navigatorKey: rootKey,
    routes: [
      GoRoute(
        path: '/auth',
        name: 'signIn',
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'sign-up',
            name: 'signUp',
            builder: (context, state) => const SignUpScreen(),
          ),
          GoRoute(
            path: 'forgot',
            name: 'forgotPassword',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/workouts',
                name: 'workouts',
                builder: (context, state) => const WorkoutsScreen(),
                routes: [
                  GoRoute(
                    path: 'exercises',
                    name: 'library',
                    builder: (context, state) => const ExerciseSearchScreen(),
                  ),
                  GoRoute(
                    path: 'exercises/:exerciseId',
                    name: 'exerciseDetail',
                    builder: (context, state) => ExerciseDetailScreen(
                      exerciseId: state.pathParameters['exerciseId']!,
                    ),
                  ),
                  // Full-screen workout session (over the shell, §14).
                  GoRoute(
                    path: 'session',
                    name: 'session',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const WorkoutSessionScreen(),
                  ),
                  GoRoute(
                    path: 'session/summary',
                    name: 'summary',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const WorkoutSummaryScreen(),
                  ),
                  GoRoute(
                    path: 'rest-day',
                    name: 'restDay',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const RestDayScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/progress',
                name: 'progress',
                builder: (context, state) => const ProgressScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'history/:sessionId',
                    name: 'historyDetail',
                    builder: (context, state) => HistoryDetailScreen(
                      sessionId: state.pathParameters['sessionId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'achievements',
                    name: 'achievements',
                    builder: (context, state) => const AchievementsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/challenges',
                name: 'challenges',
                builder: (context, state) => const ChallengesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/friends',
                name: 'friends',
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/maxes',
        name: 'maxes',
        builder: (context, state) => const MaxesScreen(),
      ),
      GoRoute(
        path: '/app/workouts/edit',
        name: 'programEditor',
        builder: (context, state) => const ProgramEditorScreen(),
      ),
      GoRoute(
        path: '/app/workouts/edit/day/:dayNumber',
        name: 'dayEditor',
        builder: (context, state) => DayEditorScreen(
          dayNumber: int.tryParse(state.pathParameters['dayNumber'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
        path: '/app/workouts/build',
        name: 'sessionBuilder',
        builder: (context, state) => const SessionBuilderScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri.path}')),
    ),
  );
});
