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
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProfileProvider = StreamProvider<AppUserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<AppUserProfile?>.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? AppUserProfile.fromDocument(snapshot) : null,
      );
});

final providerProfileProvider = StreamProvider.family<ProviderProfile?, String>(
  (ref, uid) {
    return ref
        .watch(firestoreProvider)
        .collection('provider_profiles')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? ProviderProfile.fromDocument(snapshot) : null,
        );
  },
);

final categoriesProvider = StreamProvider<List<ServiceCategory>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).watchCategories();
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
