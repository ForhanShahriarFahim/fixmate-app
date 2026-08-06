import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';
import 'package:fixmate/features/admin/admin_screens.dart';
import 'package:fixmate/features/auth/auth_screens.dart';
import 'package:fixmate/features/bookings/booking_screens.dart';
import 'package:fixmate/features/catalog/catalog_screens.dart';
import 'package:fixmate/features/provider/provider_screens.dart';
import 'package:fixmate/features/shared/shared_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final notifier = _AuthRefreshNotifier(auth);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = auth.currentUser;
      return resolveAuthRedirect(
        signedIn: user != null,
        emailVerified: user?.emailVerified == true,
        location: state.matchedLocation,
      );
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('FixMate')),
      body: const ErrorView(message: 'This FixMate page is not available.'),
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SessionGateScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => _RoleGuard(
          expectedRole: UserRole.customer,
          child: CustomerShell(
            initialIndex: shellTabIndex(
              state.uri.queryParameters['tab'],
              provider: false,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/provider',
        builder: (context, state) => _RoleGuard(
          expectedRole: UserRole.provider,
          child: ProviderShell(
            initialIndex: shellTabIndex(
              state.uri.queryParameters['tab'],
              provider: true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/provider/onboarding',
        builder: (context, state) => _RoleGuard(
          expectedRole: UserRole.provider,
          child: ProviderOnboardingScreen(
            existing: state.extra as ProviderProfile?,
          ),
        ),
      ),
      GoRoute(
        path: '/provider/service-editor',
        builder: (context, state) => _RoleGuard(
          expectedRole: UserRole.provider,
          child: ServiceEditorScreen(service: state.extra as ServiceListing?),
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const _AccountGuard(child: ProfileScreen()),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            const _AdminGuard(child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin/provider/:providerId',
        builder: (context, state) => _AdminGuard(
          child: AdminProviderReviewScreen(
            providerId: state.pathParameters['providerId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (context, state) =>
            const _AdminGuard(child: AdminCategoriesScreen()),
      ),
      GoRoute(
        path: '/provider/:providerId',
        builder: (context, state) => _AccountGuard(
          child: PublicProviderProfileScreen(
            providerId: state.pathParameters['providerId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) =>
            const _AccountGuard(child: BlockedUsersScreen()),
      ),
      GoRoute(
        path: '/service/:serviceId',
        builder: (context, state) => _AccountGuard(
          child: ServiceDetailScreen(
            serviceId: state.pathParameters['serviceId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/book/:serviceId',
        builder: (context, state) => _RoleGuard(
          expectedRole: UserRole.customer,
          child: CreateBookingScreen(
            serviceId: state.pathParameters['serviceId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/booking/:bookingId',
        builder: (context, state) => _AccountGuard(
          child: BookingDetailScreen(
            bookingId: state.pathParameters['bookingId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/booking/:bookingId/chat',
        builder: (context, state) => _AccountGuard(
          child: ChatScreen(bookingId: state.pathParameters['bookingId']!),
        ),
      ),
      GoRoute(
        path: '/legal/:document',
        builder: (context, state) =>
            LegalDocumentScreen(document: state.pathParameters['document']!),
      ),
    ],
  );
});

String? resolveAuthRedirect({
  required bool signedIn,
  required bool emailVerified,
  required String location,
}) {
  final public =
      location == '/login' ||
      location == '/register' ||
      location == '/forgot-password' ||
      location.startsWith('/legal/');
  if (!signedIn && !public) return '/login';
  if (signedIn &&
      !emailVerified &&
      location != '/verify-email' &&
      !location.startsWith('/legal/')) {
    return '/verify-email';
  }
  if (signedIn &&
      emailVerified &&
      <String>{'/login', '/register', '/verify-email'}.contains(location)) {
    return '/';
  }
  return null;
}

class _RoleGuard extends ConsumerWidget {
  const _RoleGuard({required this.expectedRole, required this.child});
  final UserRole expectedRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminMembershipProvider);
    return admin.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) => ProfileLoadErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(currentAdminMembershipProvider),
      ),
      data: (membership) {
        if (membership?.active == true) {
          _goAfterBuild(context, '/admin');
          return const Scaffold(body: LoadingView());
        }
        final profile = ref.watch(currentUserProfileProvider);
        return profile.when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (error, stack) => ProfileLoadErrorScreen(
            error: error,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (value) {
            if (value == null) {
              return MissingProfileRecoveryScreen(
                onRetry: () => ref.invalidate(currentUserProfileProvider),
              );
            }
            if (value.status != AccountStatus.active) {
              return AccountRestrictedScreen(profile: value);
            }
            if (value.role != expectedRole) {
              _goAfterBuild(context, profileDestination(value));
              return const Scaffold(body: LoadingView());
            }
            return child;
          },
        );
      },
    );
  }
}

class _AccountGuard extends ConsumerWidget {
  const _AccountGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminMembershipProvider);
    return admin.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) => ProfileLoadErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(currentAdminMembershipProvider),
      ),
      data: (membership) {
        if (membership?.active == true) {
          _goAfterBuild(context, '/admin');
          return const Scaffold(body: LoadingView());
        }
        final profile = ref.watch(currentUserProfileProvider);
        return profile.when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (error, stack) => ProfileLoadErrorScreen(
            error: error,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (value) {
            if (value == null) {
              return MissingProfileRecoveryScreen(
                onRetry: () => ref.invalidate(currentUserProfileProvider),
              );
            }
            if (value.status != AccountStatus.active) {
              return AccountRestrictedScreen(profile: value);
            }
            return child;
          },
        );
      },
    );
  }
}

class _AdminGuard extends ConsumerWidget {
  const _AdminGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminMembershipProvider);
    return admin.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) => ProfileLoadErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(currentAdminMembershipProvider),
      ),
      data: (membership) {
        if (membership?.active == true) return child;
        final profile = ref.watch(currentUserProfileProvider);
        return profile.when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (error, stack) => ProfileLoadErrorScreen(
            error: error,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (value) {
            if (value == null) {
              return MissingProfileRecoveryScreen(
                onRetry: () => ref.invalidate(currentUserProfileProvider),
              );
            }
            _goAfterBuild(context, profileDestination(value));
            return const Scaffold(body: LoadingView());
          },
        );
      },
    );
  }
}

String profileDestination(AppUserProfile profile) =>
    profile.role == UserRole.customer ? '/customer' : '/provider';

int shellTabIndex(String? tab, {required bool provider}) => switch (tab) {
  'bookings' => 1,
  'services' when provider => 2,
  'activity' => provider ? 3 : 2,
  'profile' => provider ? 4 : 3,
  _ => 0,
};

String? resolveSessionDestination({
  required bool isAdmin,
  required AppUserProfile? profile,
}) {
  if (isAdmin) return '/admin';
  return profile == null ? null : profileDestination(profile);
}

void _goAfterBuild(BuildContext context, String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.go(location);
  });
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(FirebaseAuth auth) {
    _subscription = auth.userChanges().listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
