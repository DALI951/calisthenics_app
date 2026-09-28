import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../features/onboarding/presentation/onboarding_providers.dart';
import '../features/profile/presentation/profile_providers.dart';

/// Root widget.
class CalisthenicsApp extends ConsumerWidget {
  const CalisthenicsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    // Warm the onboarding flag so the router's first redirect is accurate.
    ref.watch(onboardingControllerProvider);

    return MaterialApp.router(
      title: 'Calisthenics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
