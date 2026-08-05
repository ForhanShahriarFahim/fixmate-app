// Generated for the existing FixMate Android app by `flutterfire configure`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('FixMate v1 supports Android only.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNP-dctRT6ry_bZ1F5QgHZ2NnyGgCpZhk',
    appId: '1:186366110068:android:81a7c2859eae0bb7156421',
    messagingSenderId: '186366110068',
    projectId: 'fixmate-ce36d',
    storageBucket: 'fixmate-ce36d.firebasestorage.app',
  );
}
