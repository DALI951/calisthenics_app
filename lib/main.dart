import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'features/auth/data/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Backend bootstrap is best-effort: failure = local-only mode with
  // honest "not configured yet" messaging (never a fake backend).
  final backend = await initializeBackend();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the bootstrap result; types/indexes checked below.
        backendStatusProvider.overrideWithValue(backend),
      ],
      child: const CalisthenicsApp(),
    ),
  );
}
