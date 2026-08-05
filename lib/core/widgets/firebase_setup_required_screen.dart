import 'package:flutter/material.dart';

class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.handyman_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Connect FixMate to Firebase',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'Firebase client configuration is missing or invalid. '
                          'In FlutLab, choose Connect to Firebase, upload the matching google-services.json, '
                          'regenerate lib/core/firebase/firebase_options.dart for Android, and rebuild FixMate.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Required Firebase products: Authentication, Firestore, App Check, and Crashlytics. '
                      'Keep the project on the no-cost Spark plan.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
