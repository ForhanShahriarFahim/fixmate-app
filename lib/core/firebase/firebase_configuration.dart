import 'package:fixmate/core/firebase/firebase_options.dart';

abstract final class FirebaseConfiguration {
  static bool get isConfigured {
    final options = DefaultFirebaseOptions.currentPlatform;
    return !options.projectId.startsWith('REPLACE_') &&
        !options.apiKey.startsWith('REPLACE_') &&
        !options.appId.startsWith('REPLACE_');
  }
}
