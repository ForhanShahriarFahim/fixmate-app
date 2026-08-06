import 'package:firebase_core/firebase_core.dart';
import 'package:fixmate/core/firebase/firebase_options.dart';

abstract final class FirebaseConfiguration {
  static const expectedProjectId = 'fixmate-ce36d';
  static const expectedAndroidAppId =
      '1:186366110068:android:81a7c2859eae0bb7156421';

  /// App Check must be registered in Firebase Console before the client SDK
  /// is activated. Keep it opt-in while enforcement is disabled so an
  /// incomplete setup cannot delay Authentication or Firestore.
  static const appCheckEnabled = bool.fromEnvironment(
    'FIXMATE_ENABLE_APP_CHECK',
  );

  static bool get isConfigured {
    try {
      return hasExpectedIdentity(DefaultFirebaseOptions.currentPlatform);
    } on UnsupportedError {
      return false;
    }
  }

  static bool hasExpectedIdentity(FirebaseOptions options) {
    return options.projectId == expectedProjectId &&
        options.appId == expectedAndroidAppId &&
        options.apiKey.isNotEmpty &&
        options.messagingSenderId.isNotEmpty;
  }
}
