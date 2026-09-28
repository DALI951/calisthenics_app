import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../app/configuration/app_config.dart';
import '../../app/configuration/app_env.dart';
import 'backend_status.dart';

/// Initializes Firebase according to the environment and wires emulators.
///
/// Failure here is NOT fatal: the app boots in local-only mode with
/// [BackendStatus.unavailable] and shows honest errors on backend actions.
/// This is what lets the app develop and run before Dali's Firebase project
/// exists, and what keeps CI green without secrets.
Future<BackendStatus> initializeBackend() async {
  final env = AppEnv.fromName(const String.fromEnvironment('APP_ENV'));

  if (env.isProd && !kDebugMode) {
    // Prod: platform config (google-services.json) is required.
    try {
      await Firebase.initializeApp();
      return BackendStatus.available;
    } catch (e, st) {
      debugPrint('Firebase init (prod) failed: $e');
      debugPrintStack(stackTrace: st);
      return BackendStatus.unavailable;
    }
  }

  // Dev / debug builds: programmatic emulator options.
  try {
    final options = await AppConfig.resolveOptions(env);
    await Firebase.initializeApp(options: options);

    if (env.useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(
        AppConfig.emulatorAuthHost,
        AppConfig.emulatorAuthPort,
      );
      FirebaseFirestore.instance.useFirestoreEmulator(
        AppConfig.emulatorFirestoreHost,
        AppConfig.emulatorFirestorePort,
      );
      FirebaseDatabase.instance.useDatabaseEmulator(
        AppConfig.emulatorDatabaseHost,
        AppConfig.emulatorDatabasePort,
      );
      FirebaseStorage.instance.useStorageEmulator(
        AppConfig.emulatorStorageHost,
        AppConfig.emulatorStoragePort,
      );
      // App Check is not required against emulators.
      return BackendStatus.emulator;
    }

    await _setupAppCheck();
    return BackendStatus.available;
  } catch (e, st) {
    debugPrint('Firebase init (dev) failed: $e');
    debugPrintStack(stackTrace: st);
    return BackendStatus.unavailable;
  }
}

Future<void> _setupAppCheck() async {
  // Debug providers assert "debug" attestation so local/prod-debug builds
  // pass App Check without Play Integrity setup. Production releases are
  // expected to switch to Play Integrity / Device Check (docs/firebase-setup.md).
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidDebugProvider(),
    providerApple: const AppleDebugProvider(),
  );
}
