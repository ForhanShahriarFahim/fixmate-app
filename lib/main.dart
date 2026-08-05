import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixmate/app.dart';
import 'package:fixmate/core/firebase/firebase_configuration.dart';
import 'package:fixmate/core/firebase/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!FirebaseConfiguration.isConfigured) {
    runApp(const ProviderScope(child: FixMateApp(firebaseConfigured: false)));
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (error, stack) {
    debugPrint('FixMate Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stack);
    runApp(
      const ProviderScope(
        child: FixMateApp(
          firebaseConfigured: false,
          firebaseSetupMessage:
              'FixMate could not safely connect to Firebase. Check the registered Android or web app, generated Firebase options, network connection, and platform setup, then rebuild the app.',
        ),
      ),
    );
    return;
  }

  runZonedGuarded(
    () => runApp(
      const ProviderScope(child: FixMateApp(firebaseConfigured: true)),
    ),
    (Object error, StackTrace stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}
