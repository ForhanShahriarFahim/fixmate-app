import 'package:fixmate/core/firebase/firebase_options.dart';

abstract final class FirebaseConfiguration {
  static const expectedProjectId = 'fixmate-ce36d';
  static const expectedAndroidAppId =
      '1:186366110068:android:81a7c2859eae0bb7156421';

  static bool get isConfigured {
    final options = DefaultFirebaseOptions.currentPlatform;
    return options.projectId == expectedProjectId &&
        options.appId == expectedAndroidAppId &&
        options.apiKey.isNotEmpty &&
        options.messagingSenderId.isNotEmpty;
  }
}
