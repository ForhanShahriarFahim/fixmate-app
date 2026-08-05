import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixmate/core/routing/app_router.dart';
import 'package:fixmate/core/theme/app_theme.dart';
import 'package:fixmate/core/widgets/firebase_setup_required_screen.dart';

class FixMateApp extends ConsumerWidget {
  const FixMateApp({
    required this.firebaseConfigured,
    this.firebaseSetupMessage,
    super.key,
  });

  final bool firebaseConfigured;
  final String? firebaseSetupMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!firebaseConfigured) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FixMate setup',
        theme: AppTheme.light(),
        home: FirebaseSetupRequiredScreen(message: firebaseSetupMessage),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FixMate',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
