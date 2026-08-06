import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/theme/app_theme.dart';
import 'package:fixmate/features/auth/auth_screens.dart';

Widget _loginApp(SignInAction action, {double textScale = 1}) => ProviderScope(
  overrides: [signInActionProvider.overrideWith((ref) => action)],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const LoginScreen(),
  ),
);

Future<void> _enterValidLogin(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'person@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
}

Widget _recoveryApp({
  required SignOutAction signOut,
  required String initialLocation,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/recovery',
        builder: (context, state) => const MissingProfileRecoveryScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login destination'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [signOutActionProvider.overrideWith((ref) => signOut)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('incorrect credentials remain on login with a safe message', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _loginApp(({required email, required password}) async {
        attempts++;
        throw FirebaseAuthException(code: 'invalid-credential');
      }),
    );
    await _enterValidLogin(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('malformed email is rejected before authentication', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _loginApp(({required email, required password}) async {
        attempts++;
      }),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(attempts, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('login prevents duplicate in-flight submissions', (tester) async {
    final completion = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      _loginApp(({required email, required password}) {
        attempts++;
        return completion.future;
      }),
    );
    await _enterValidLogin(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Signing in…'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Signing in…'));
    await tester.pump();
    expect(attempts, 1);

    completion.completeError(FirebaseAuthException(code: 'invalid-credential'));
    await tester.pumpAndSettle();
  });

  testWidgets('missing profile return action signs out before login', (
    tester,
  ) async {
    var signOuts = 0;
    await tester.pumpWidget(
      _recoveryApp(
        initialLocation: '/recovery',
        signOut: () async {
          signOuts++;
        },
      ),
    );
    await tester.tap(find.text('Return to sign in'));
    await tester.pumpAndSettle();

    expect(signOuts, 1);
    expect(find.text('Login destination'), findsOneWidget);
  });

  testWidgets('Android Back from missing profile performs safe sign out', (
    tester,
  ) async {
    var signOuts = 0;
    await tester.pumpWidget(
      _recoveryApp(
        initialLocation: '/recovery',
        signOut: () async {
          signOuts++;
        },
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(signOuts, 1);
    expect(find.text('Login destination'), findsOneWidget);
  });

  testWidgets('profile loading error is retryable and not called missing', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signOutActionProvider.overrideWith((ref) => () async {})],
        child: MaterialApp(
          home: ProfileLoadErrorScreen(
            error: FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            ),
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.text('FixMate could not load your account'), findsOneWidget);
    expect(find.textContaining('profile is missing'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('slow startup exposes retry and safe sign-in recovery', (
    tester,
  ) async {
    var retries = 0;
    var signOuts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupLoadingView(
          stageLabel: 'account profile',
          takingLonger: true,
          signingOut: false,
          onRetry: () => retries++,
          onReturnToSignIn: () => signOuts++,
        ),
      ),
    );

    expect(find.text('FixMate'), findsOneWidget);
    expect(find.textContaining('confirm your account profile'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Try again'));
    await tester.ensureVisible(find.text('Return to sign in'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Return to sign in'));
    expect(retries, 1);
    expect(signOuts, 1);
  });

  testWidgets('login form has no overflow at 320dp and 2x text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _loginApp(({required email, required password}) async {}, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets(
    'registration form has no initial overflow at 320dp and 2x text scaling',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const RegisterScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Create account'), findsWidgets);
    },
  );
}
