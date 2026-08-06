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
  var firebaseInitialized = false;

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (!FirebaseConfiguration.isConfigured) {
        runApp(
          const ProviderScope(child: FixMateApp(firebaseConfigured: false)),
        );
        return;
      }

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseInitialized = true;

        if (FirebaseConfiguration.appCheckEnabled && kDebugMode) {
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidDebugProvider(),
          );
        }
        FlutterError.onError = (FlutterErrorDetails details) {
          if (kDebugMode) FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
          if (kDebugMode) {
            debugPrint('Uncaught FixMate platform error: ${error.runtimeType}');
            debugPrintStack(stackTrace: stack);
          }
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } catch (error, stack) {
        debugPrint(
          'FixMate Firebase initialization failed: ${error.runtimeType}',
        );
        debugPrintStack(stackTrace: stack);
        runApp(
          const ProviderScope(
            child: FixMateApp(
              firebaseConfigured: false,
              firebaseSetupMessage:
                  'FixMate could not safely connect to Firebase. Check the registered Android app, generated Firebase options, network connection, and platform setup, then rebuild the app.',
            ),
          ),
        );
        return;
      }

      runApp(const ProviderScope(child: FixMateApp(firebaseConfigured: true)));
    },
    (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('Uncaught FixMate zone error: ${error.runtimeType}');
        debugPrintStack(stackTrace: stack);
      }
      if (firebaseInitialized) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
      }
    },
  );
}
