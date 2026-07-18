import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/validators.dart';

class MarketplaceRepository {
  const MarketplaceRepository(this._firestore, this._functions, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  Stream<List<ServiceCategory>> watchCategories() => _firestore
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(ServiceCategory.fromDocument)
            .toList(growable: false),
      );

  Stream<List<ServiceListing>> watchServices({
    String? categoryId,
    String? districtCode,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('services')
        .where('status', isEqualTo: ServiceStatus.active.name);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (districtCode != null && districtCode.isNotEmpty) {
      query = query.where('districtCode', isEqualTo: districtCode);
    }
    return query
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ServiceListing.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<ServiceListing?> watchService(String serviceId) => _firestore
      .collection('services')
      .doc(serviceId)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? ServiceListing.fromDocument(snapshot) : null,
      );

  Stream<List<ServiceListing>> watchProviderServices(String providerId) =>
      _firestore
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ServiceListing.fromDocument)
                .toList(growable: false),
          );

  Future<void> saveProviderProfile({
    required String providerId,
    required String publicName,
    required String bio,
    required int experienceYears,
    required String divisionCode,
    required String districtCode,
    required List<String> serviceAreas,
    String? avatarUrl,
  }) async {
    final reference = _firestore
        .collection('provider_profiles')
        .doc(providerId);
    final existing = await reference.get();
    final labels = serviceAreas
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final payload = <String, dynamic>{
      'providerId': providerId,
      'publicName': publicName.trim(),
      'avatarUrl': avatarUrl,
      'bio': bio.trim(),
      'experienceYears': experienceYears,
      'divisionCode': divisionCode,
      'districtCode': districtCode,
      'serviceAreaLabels': labels,
      'serviceAreaKeys': labels
          .map(Validators.normalizeKey)
          .toList(growable: false),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      payload.addAll(<String, dynamic>{
        'approvalStatus': ProviderApprovalStatus.pending.name,
        'ratingAverage': 0.0,
        'reviewCount': 0,
        'completedBookings': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await reference.set(payload, SetOptions(merge: true));
  }

  Future<String> saveService({
    String? serviceId,
    required String providerId,
    required String providerName,
    required String categoryId,
    required String title,
    required String description,
    required int priceBdt,
    required String districtCode,
    required List<String> areaLabels,
    required ServiceStatus status,
    String? coverImageUrl,
  }) async {
    final reference = serviceId == null
        ? _firestore.collection('services').doc()
        : _firestore.collection('services').doc(serviceId);
    final normalizedTitle = title.trim().toLowerCase();
    final tokens = normalizedTitle
        .split(RegExp(r'\s+'))
        .where((value) => value.length > 1)
        .toSet()
        .toList();
    final payload = <String, dynamic>{
      'providerId': providerId,
      'providerName': providerName.trim(),
      'categoryId': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'priceBdt': priceBdt,
      'coverImageUrl': coverImageUrl,
      'districtCode': districtCode,
      'areaLabels': areaLabels,
      'areaKeys': areaLabels
          .map(Validators.normalizeKey)
          .toList(growable: false),
      'searchTokens': tokens,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (serviceId == null) {
      payload.addAll(<String, dynamic>{
        'providerRating': 0.0,
        'reviewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await reference.set(payload, SetOptions(merge: true));
    return reference.id;
  }

  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final reference = _storage.ref(path);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  Stream<List<Booking>> watchBookings({
    required String uid,
    required UserRole role,
  }) {
    final field = role == UserRole.customer ? 'customerId' : 'providerId';
    return _firestore
        .collection('bookings')
        .where(field, isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Booking.fromDocument).toList(growable: false),
        );
  }

  Stream<Booking?> watchBooking(String bookingId) => _firestore
      .collection('bookings')
      .doc(bookingId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists ? Booking.fromDocument(snapshot) : null,
      );

  Stream<BookingContact?> watchBookingContact(String bookingId) => _firestore
      .collection('bookings')
      .doc(bookingId)
      .collection('private')
      .doc('contact')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? BookingContact.fromDocument(snapshot) : null,
      );

  Stream<List<BookingEvent>> watchBookingEvents(String bookingId) => _firestore
      .collection('bookings')
      .doc(bookingId)
      .collection('events')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(BookingEvent.fromDocument)
            .toList(growable: false),
      );

  Stream<List<ChatMessage>> watchMessages(String bookingId) => _firestore
      .collection('bookings')
      .doc(bookingId)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(ChatMessage.fromDocument).toList(growable: false),
      );

  Stream<List<ServiceReview>> watchProviderReviews(String providerId) =>
      _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ServiceReview.fromDocument)
                .toList(growable: false),
          );

  Stream<List<FixMateNotification>> watchNotifications(String uid) => _firestore
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(FixMateNotification.fromDocument)
            .toList(growable: false),
      );

  Future<void> markNotificationRead(String uid, String notificationId) =>
      _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(notificationId)
          .update(<String, dynamic>{'readAt': FieldValue.serverTimestamp()});

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    return result.data;
  }
}
