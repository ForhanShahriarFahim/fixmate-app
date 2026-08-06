import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/data/repositories/auth_repository.dart';
import 'package:fixmate/core/data/repositories/marketplace_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// Refreshes the cached Firebase Authentication session before protected
/// Firestore listeners are attached. Android can restore a locally cached user
/// whose ID token is stale; waiting for a fresh token avoids leaving Firestore
/// listeners pending indefinitely with that stale session.
final authenticatedSessionReadyProvider = FutureProvider<User?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  await user
      .getIdTokenResult(true)
      .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Firebase could not refresh the sign-in session in time.',
        ),
      );
  return user;
});

typedef SignInAction =
    Future<void> Function({required String email, required String password});
typedef SignOutAction = Future<void> Function();

final signInActionProvider = Provider<SignInAction>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ({required email, required password}) async {
    await repository.signIn(email: email, password: password);
  };
});

final signOutActionProvider = Provider<SignOutAction>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.signOut;
});

typedef EmailVerificationRefresher = Future<bool> Function();

final emailVerificationRefresherProvider = Provider<EmailVerificationRefresher>(
  (ref) {
    final repository = ref.watch(authRepositoryProvider);
    return () async {
      final user = await repository.reloadUser();
      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserProfileProvider);
      return user.emailVerified;
    };
  },
);

class ProviderProfileDraft {
  const ProviderProfileDraft({
    required this.publicName,
    required this.bio,
    required this.experienceYears,
    required this.divisionCode,
    required this.districtCode,
    required this.serviceAreas,
  });

  final String publicName;
  final String bio;
  final int experienceYears;
  final String divisionCode;
  final String districtCode;
  final List<String> serviceAreas;
}

typedef ProviderProfileSubmitter =
    Future<ProviderProfile> Function(ProviderProfileDraft draft);

final providerProfileSubmitterProvider = Provider<ProviderProfileSubmitter>((
  ref,
) {
  final auth = ref.watch(firebaseAuthProvider);
  final repository = ref.watch(marketplaceRepositoryProvider);
  return (draft) {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Your session expired. Sign in again to continue.');
    }
    return repository.saveProviderProfile(
      providerId: user.uid,
      publicName: draft.publicName,
      bio: draft.bio,
      experienceYears: draft.experienceYears,
      divisionCode: draft.divisionCode,
      districtCode: draft.districtCode,
      serviceAreas: draft.serviceAreas,
    );
  };
});

final currentUserProfileProvider = StreamProvider<AppUserProfile?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream<AppUserProfile?>.empty();
  if (auth.hasError) return Stream<AppUserProfile?>.error(auth.error!);
  final user = auth.value;
  if (user == null) return Stream<AppUserProfile?>.value(null);
  final snapshots = ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots();
  return _watchUserProfile(snapshots);
});

/// Secure administrator membership is separate from the editable FixMate user
/// profile. The client can only read its own `admins/{uid}` document; rules
/// prohibit every client from creating or changing administrator membership.
final currentAdminMembershipProvider = StreamProvider<AdminMembership?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream<AdminMembership?>.empty();
  if (auth.hasError) return Stream<AdminMembership?>.error(auth.error!);
  final user = auth.value;
  if (user == null) return Stream<AdminMembership?>.value(null);
  final membership = ref
      .watch(firestoreProvider)
      .collection('admins')
      .doc(user.uid);
  return _watchOwnAdminMembership(membership);
});

final userProfileProvider = StreamProvider.family<AppUserProfile?, String>((
  ref,
  uid,
) {
  final snapshots = ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots();
  return _watchUserProfile(snapshots);
});

Stream<AppUserProfile?> _watchUserProfile(
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
) async* {
  await for (final snapshot in _confirmedDocuments(snapshots)) {
    if (snapshot.exists) {
      yield AppUserProfile.fromDocument(snapshot);
    } else {
      // A missing document is confirmed only by the server. An empty offline
      // cache stays in loading/error recovery instead of impersonating a
      // confirmed missing FixMate profile.
      yield null;
    }
  }
}

Stream<AdminMembership?> _watchOwnAdminMembership(
  DocumentReference<Map<String, dynamic>> membership,
) async* {
  try {
    final initial = await membership
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Firebase did not confirm administrator access in time.',
          ),
        );
    yield initial.exists ? AdminMembership.fromDocument(initial) : null;

    await for (final snapshot in membership.snapshots()) {
      if (snapshot.exists) {
        yield AdminMembership.fromDocument(snapshot);
      } else {
        yield null;
      }
    }
  } on FirebaseException catch (error) {
    // Treating a denied membership read as "not an admin" grants no authority
    // and keeps ordinary accounts on their role-specific flow.
    if (error.code == 'permission-denied') {
      yield null;
      return;
    }
    rethrow;
  }
}

final providerProfileProvider = StreamProvider.family<ProviderProfile?, String>(
  (ref, uid) {
    final snapshots = ref
        .watch(firestoreProvider)
        .collection('provider_profiles')
        .doc(uid)
        .snapshots();
    return _watchProviderProfile(snapshots);
  },
);

Stream<ProviderProfile?> _watchProviderProfile(
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
) async* {
  await for (final snapshot in _confirmedDocuments(snapshots)) {
    if (snapshot.exists) {
      yield ProviderProfile.fromDocument(snapshot);
    } else {
      yield null;
    }
  }
}

Stream<DocumentSnapshot<Map<String, dynamic>>> _confirmedDocuments(
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
) async* {
  final iterator = StreamIterator(snapshots);
  final confirmationDeadline = DateTime.now().add(const Duration(seconds: 15));
  try {
    var confirmed = false;
    while (!confirmed) {
      final remaining = confirmationDeadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Firebase did not confirm the account record in time.',
        );
      }
      final hasNext = await iterator.moveNext().timeout(remaining);
      if (!hasNext) return;
      final snapshot = iterator.current;
      if (snapshot.exists || !snapshot.metadata.isFromCache) {
        confirmed = true;
        yield snapshot;
      }
    }
    while (await iterator.moveNext()) {
      final snapshot = iterator.current;
      if (snapshot.exists || !snapshot.metadata.isFromCache) yield snapshot;
    }
  } finally {
    await iterator.cancel();
  }
}

final categoriesProvider = StreamProvider<List<ServiceCategory>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).watchCategories();
});

final adminCategoriesProvider = StreamProvider<List<ServiceCategory>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).watchAllCategories();
});

final providerReviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummary, String>((ref, providerId) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .getProviderReviewSummary(providerId);
    });

final providerDashboardStatsProvider = FutureProvider.autoDispose
    .family<ProviderDashboardStats, String>((ref, providerId) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .getProviderDashboardStats(providerId);
    });

final serviceProvider = StreamProvider.family<ServiceListing?, String>((
  ref,
  serviceId,
) {
  return ref.watch(marketplaceRepositoryProvider).watchService(serviceId);
});

final bookingProvider = StreamProvider.family<Booking?, String>((
  ref,
  bookingId,
) {
  return ref.watch(marketplaceRepositoryProvider).watchBooking(bookingId);
});
