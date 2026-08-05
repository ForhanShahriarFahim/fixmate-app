import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:fixmate/core/firebase/firebase_options.dart';

abstract final class FirebaseConfiguration {
  static const expectedProjectId = 'fixmate-ce36d';
  static const expectedAndroidAppId =
      '1:186366110068:android:81a7c2859eae0bb7156421';
  static const expectedWebAppId = '1:186366110068:web:cd6be69830847ab9156421';

  static bool get isConfigured {
    try {
      return hasExpectedIdentity(
        DefaultFirebaseOptions.currentPlatform,
        isWebPlatform: kIsWeb,
      );
    } on UnsupportedError {
      return false;
    }
  }

  static bool hasExpectedIdentity(
    FirebaseOptions options, {
    required bool isWebPlatform,
  }) {
    final expectedAppId = isWebPlatform
        ? expectedWebAppId
        : expectedAndroidAppId;
    return options.projectId == expectedProjectId &&
        options.appId == expectedAppId &&
        options.apiKey.isNotEmpty &&
        options.messagingSenderId.isNotEmpty;
  }
}
