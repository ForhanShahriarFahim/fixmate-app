import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/widgets/firebase_setup_required_screen.dart';

void main() {
  testWidgets('explains Firebase setup when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FirebaseSetupRequiredScreen()),
    );
    expect(find.text('Connect FixMate to Firebase'), findsOneWidget);
    expect(find.textContaining('google-services.json'), findsOneWidget);
  });
}
