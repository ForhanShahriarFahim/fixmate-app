import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/firebase/firebase_configuration.dart';
import 'package:fixmate/core/firebase/firebase_options.dart';
import 'package:fixmate/core/widgets/firebase_setup_required_screen.dart';

void main() {
  test('uses the verified FixMate Android Firebase project', () {
    expect(FirebaseConfiguration.isConfigured, isTrue);
    expect(
      DefaultFirebaseOptions.android.projectId,
      FirebaseConfiguration.expectedProjectId,
    );
    expect(
      DefaultFirebaseOptions.android.appId,
      FirebaseConfiguration.expectedAndroidAppId,
    );
    expect(
      FirebaseConfiguration.hasExpectedIdentity(DefaultFirebaseOptions.android),
      isTrue,
    );
  });

  testWidgets('explains Firebase setup when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FirebaseSetupRequiredScreen()),
    );
    expect(find.text('Connect FixMate to Firebase'), findsOneWidget);
    expect(find.textContaining('firebase_options.dart'), findsOneWidget);
  });

  testWidgets('shows a safe Firebase initialization failure', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseSetupRequiredScreen(
          message: 'FixMate could not safely connect to Firebase.',
        ),
      ),
    );
    expect(
      find.text('FixMate could not safely connect to Firebase.'),
      findsOneWidget,
    );
  });
}
