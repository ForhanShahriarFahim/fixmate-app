import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixmate/core/data/repositories/marketplace_policies.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/validators.dart';

/// Firebase Spark-compatible marketplace data access.
///
/// Every marketplace mutation is committed directly to Firestore. The client
/// performs friendly preflight checks, while Firestore Security Rules remain
/// the authoritative validator for roles, state transitions, related writes,
/// contact privacy, and immutable fields.
class MarketplaceRepository {
  const MarketplaceRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ServiceCategory>> watchCategories() =>
      _watchQueryWithServerStart(
        _firestore
            .collection('categories')
            .where('isActive', isEqualTo: true)
            .orderBy('order'),
      ).map(
        (snapshot) => snapshot.docs
            .map(ServiceCategory.fromDocument)
            .toList(growable: false),
      );

  Stream<List<ServiceCategory>> watchAllCategories() =>
      _watchQueryWithServerStart(
        _firestore.collection('categories').orderBy('order'),
      ).map(
        (snapshot) => snapshot.docs
            .map(ServiceCategory.fromDocument)
            .toList(growable: false),
      );

  Future<void> saveCategory({
    required String categoryId,
    required bool createNew,
    required String name,
    required String iconKey,
    required int order,
    required bool isActive,
  }) async {
    final user = _requireAuthUser();
    final membership = await _firestore
        .collection('admins')
        .doc(user.uid)
        .get();
    if (!membership.exists || membership.data()?['active'] != true) {
      throw StateError('Administrator access is required.');
    }
    final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.length < 2 || normalizedName.length > 60) {
      throw ArgumentError('Use a category name between 2 and 60 characters.');
    }
    if (!RegExp(r'^[a-z][a-z0-9-]{1,49}$').hasMatch(categoryId)) {
      throw ArgumentError(
        'Use a lowercase category ID such as water-filter-repair.',
      );
    }
    const allowedIcons = <String>{
      'electrical',
      'plumbing',
      'cleaning',
      'ac',
      'appliance',
      'painting',
      'handyman',
    };
    if (!allowedIcons.contains(iconKey)) {
      throw ArgumentError('Choose a supported category icon.');
    }
    if (order < 0 || order > 999) {
      throw ArgumentError('Category order must be between 0 and 999.');
    }
    final reference = _firestore.collection('categories').doc(categoryId);
    final existing = await reference.get();
    if (createNew && existing.exists) {
      throw StateError('That category ID is already in use.');
    }
    if (!createNew && !existing.exists) {
      throw StateError('This category no longer exists.');
    }
    final payload = <String, dynamic>{
      'name': normalizedName,
      'iconKey': iconKey,
      'order': order,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (createNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await reference.set(payload, SetOptions(merge: !createNew));
  }

  Future<void> deleteCategory(String categoryId) async {
    final user = _requireAuthUser();
    final membership = await _firestore
        .collection('admins')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (!membership.exists || membership.data()?['active'] != true) {
      throw StateError('Administrator access is required.');
    }
    if (!RegExp(r'^[a-z][a-z0-9-]{1,49}$').hasMatch(categoryId)) {
      throw ArgumentError('The category ID is invalid.');
    }

    final reference = _firestore.collection('categories').doc(categoryId);
    final category = await reference
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (!category.exists) {
      throw StateError('This category has already been deleted.');
    }
    if (category.data()?['isActive'] == true) {
      throw StateError('Deactivate this category before deleting it.');
    }

    final referencedServices = await _firestore
        .collection('services')
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (referencedServices.docs.isNotEmpty) {
      throw StateError(
        'This category is still used by a service. Reassign every service to another active category before deleting it.',
      );
    }

    await reference.delete().timeout(const Duration(seconds: 15));
  }

  Stream<List<ServiceListing>> watchServices({
    String? categoryId,
    String? districtCode,
    int limit = 20,
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
    return _watchEligibleServices(query.limit(limit.clamp(1, 100)));
  }

  Stream<List<ServiceListing>> watchProviderPublicServices(
    String providerId, {
    int limit = 20,
  }) => _watchEligibleServices(
    _firestore
        .collection('services')
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: ServiceStatus.active.name)
        .limit(limit.clamp(1, 100)),
  );

  Stream<List<ServiceListing>> _watchEligibleServices(
    Query<Map<String, dynamic>> query,
  ) {
    late final StreamController<List<ServiceListing>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? serviceSub;
    final profileSubs =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final eligibility = <String, bool>{};
    var services = const <ServiceListing>[];

    void emit() {
      if (controller.isClosed) return;
      controller.add(
        services
            .where((service) => eligibility[service.providerId] == true)
            .toList(growable: false),
      );
    }

    Future<void> syncProviders(Set<String> providerIds) async {
      final removed = profileSubs.keys
          .where((providerId) => !providerIds.contains(providerId))
          .toList(growable: false);
      for (final providerId in removed) {
        await profileSubs.remove(providerId)?.cancel();
        eligibility.remove(providerId);
      }
      for (final providerId in providerIds) {
        if (profileSubs.containsKey(providerId)) continue;
        eligibility[providerId] = false;
        profileSubs[providerId] = _firestore
            .collection('provider_profiles')
            .doc(providerId)
            .snapshots()
            .listen(
              (snapshot) {
                eligibility[providerId] =
                    snapshot.exists &&
                    ProviderProfile.fromDocument(snapshot).isBookable;
                emit();
              },
              onError: (Object _) {
                eligibility[providerId] = false;
                emit();
              },
            );
      }
      emit();
    }

    controller = StreamController<List<ServiceListing>>(
      onListen: () {
        serviceSub = query.snapshots().listen((snapshot) {
          services = snapshot.docs
              .map(ServiceListing.fromDocument)
              .toList(growable: false);
          unawaited(
            syncProviders(
              services.map((service) => service.providerId).toSet(),
            ),
          );
        }, onError: controller.addError);
      },
      onCancel: () async {
        await serviceSub?.cancel();
        for (final subscription in profileSubs.values) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Stream<ServiceListing?> watchService(String serviceId) => _firestore
      .collection('services')
      .doc(serviceId)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? ServiceListing.fromDocument(snapshot) : null,
      );

  Stream<List<ServiceListing>> watchProviderServices(
    String providerId, {
    int limit = 50,
  }) => _firestore
      .collection('services')
      .where('providerId', isEqualTo: providerId)
      .orderBy('updatedAt', descending: true)
      .limit(limit.clamp(1, 100))
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(ServiceListing.fromDocument)
            .toList(growable: false),
      );

  Stream<List<ProviderProfile>> watchProviderApplications({
    ProviderApprovalStatus status = ProviderApprovalStatus.pending,
    int limit = 50,
  }) => _firestore
      .collection('provider_profiles')
      .where('approvalStatus', isEqualTo: status.name)
      .limit(limit.clamp(1, 100))
      .snapshots()
      .map((snapshot) {
        final profiles = snapshot.docs
            .map(ProviderProfile.fromDocument)
            .toList(growable: true);
        profiles.sort(
          (left, right) =>
              (right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
        );
        return List<ProviderProfile>.unmodifiable(profiles);
      });

  Future<void> reviewProviderApplication({
    required String providerId,
    required ProviderApprovalStatus decision,
    String rejectionReason = '',
  }) async {
    final reviewer = _requireAuthUser();
    if (decision != ProviderApprovalStatus.approved &&
        decision != ProviderApprovalStatus.rejected) {
      throw ArgumentError('Choose approve or reject.');
    }
    final reason = rejectionReason.trim();
    if (decision == ProviderApprovalStatus.rejected && reason.length < 3) {
      throw ArgumentError('Enter a rejection reason of at least 3 characters.');
    }
    if (reason.length > 500) {
      throw ArgumentError(
        'The rejection reason must be 500 characters or less.',
      );
    }

    final reference = _firestore
        .collection('provider_profiles')
        .doc(providerId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('This provider application no longer exists.');
      }
      final profile = ProviderProfile.fromDocument(snapshot);
      if (profile.approvalStatus != ProviderApprovalStatus.pending) {
        throw StateError('This provider application was already reviewed.');
      }
      transaction.update(reference, <String, dynamic>{
        'approvalStatus': decision.name,
        'marketplaceVisible': decision == ProviderApprovalStatus.approved,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer.uid,
        'rejectionReason': decision == ProviderApprovalStatus.rejected
            ? reason
            : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<ProviderProfile> saveProviderProfile({
    required String providerId,
    required String publicName,
    required String bio,
    required int experienceYears,
    required String divisionCode,
    required String districtCode,
    required List<String> serviceAreas,
  }) async {
    final reference = _firestore
        .collection('provider_profiles')
        .doc(providerId);
    final existing = await reference.get(
      const GetOptions(source: Source.server),
    );
    final labels = _normalizedLabels(serviceAreas);
    if (labels.isEmpty || labels.length > 10) {
      throw ArgumentError('Enter between 1 and 10 unique service areas.');
    }
    final payload = <String, dynamic>{
      'providerId': providerId,
      'publicName': publicName.trim(),
      'avatarUrl': null,
      'bio': bio.trim(),
      'experienceYears': experienceYears,
      'divisionCode': divisionCode,
      'districtCode': districtCode,
      'serviceAreaLabels': labels,
      'serviceAreaKeys': labels
          .map(Validators.normalizeKey)
          .toList(growable: false),
      // Any coverage or identity edit requires a fresh console review. The
      // provider can never make this profile publicly bookable.
      'approvalStatus': ProviderApprovalStatus.pending.name,
      'marketplaceVisible': false,
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      payload.addAll(<String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await reference.set(payload, SetOptions(merge: true));
    final confirmed = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!confirmed.exists) {
      throw StateError(
        'Firebase did not confirm the provider application. Try again.',
      );
    }
    final profile = ProviderProfile.fromDocument(confirmed);
    if (profile.providerId != providerId ||
        profile.approvalStatus != ProviderApprovalStatus.pending ||
        profile.marketplaceVisible) {
      throw StateError(
        'Firebase returned an unexpected provider application state. Contact FixMate support.',
      );
    }
    return profile;
  }

  Future<String> saveService({
    String? serviceId,
    required String providerId,
    required String categoryId,
    required String title,
    required String description,
    required int priceBdt,
    required String districtCode,
    required List<String> areaLabels,
    required ServiceStatus status,
  }) async {
    final categorySnapshot = await _firestore
        .collection('categories')
        .doc(categoryId)
        .get();
    if (!categorySnapshot.exists ||
        categorySnapshot.data()?['isActive'] != true) {
      throw StateError(
        'Choose an active service category. Ask an administrator if the category you need is missing.',
      );
    }
    final profileSnapshot = await _firestore
        .collection('provider_profiles')
        .doc(providerId)
        .get();
    if (!profileSnapshot.exists) {
      throw StateError('Complete your provider profile first.');
    }
    final profile = ProviderProfile.fromDocument(profileSnapshot);
    if (profile.providerId != providerId || !profile.isBookable) {
      throw StateError('Provider approval is required to manage services.');
    }
    final labels = _normalizedLabels(areaLabels);
    final keys = labels.map(Validators.normalizeKey).toList(growable: false);
    if (districtCode != profile.districtCode ||
        !_sameStrings(labels, profile.serviceAreaLabels) ||
        !_sameStrings(keys, profile.serviceAreaKeys)) {
      throw ArgumentError(
        'Service coverage must match the currently approved provider profile.',
      );
    }
    final reference = serviceId == null
        ? _firestore.collection('services').doc()
        : _firestore.collection('services').doc(serviceId);
    final normalizedTitle = title.trim().toLowerCase();
    final tokens = normalizedTitle
        .split(RegExp(r'\s+'))
        .where((value) => value.length > 1)
        .toSet()
        .take(20)
        .toList();
    final payload = <String, dynamic>{
      'providerId': providerId,
      'providerName': profile.publicName,
      'categoryId': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'priceBdt': priceBdt,
      'coverImageUrl': null,
      'districtCode': districtCode,
      'areaLabels': labels,
      'areaKeys': keys,
      'searchTokens': tokens,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (serviceId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await reference.set(payload, SetOptions(merge: true));
    return reference.id;
  }

  Stream<List<Booking>> watchBookings({
    required String uid,
    required UserRole role,
    int limit = 50,
  }) {
    final field = role == UserRole.customer ? 'customerId' : 'providerId';
    return _firestore
        .collection('bookings')
        .where(field, isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, 100))
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
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(BookingEvent.fromDocument)
            .toList(growable: false),
      );

  Stream<List<ChatMessage>> watchMessages(String bookingId, {int limit = 50}) =>
      _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('messages')
          .orderBy('createdAt')
          .limitToLast(limit.clamp(1, 200))
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ChatMessage.fromDocument)
                .toList(growable: false),
          );

  Stream<List<ServiceReview>> watchProviderReviews(
    String providerId, {
    int limit = 20,
  }) =>
      _watchQueryWithServerStart(
        _firestore
            .collection('reviews')
            .where('providerId', isEqualTo: providerId)
            .orderBy('createdAt', descending: true)
            .limit(limit.clamp(1, 100)),
      ).map(
        (snapshot) => snapshot.docs
            .map(ServiceReview.fromDocument)
            .toList(growable: false),
      );

  Stream<ServiceReview?> watchBookingReview(String bookingId) =>
      _watchDocumentWithServerStart(
        _firestore.collection('reviews').doc(bookingId),
      ).map(
        (snapshot) =>
            snapshot.exists ? ServiceReview.fromDocument(snapshot) : null,
      );

  Future<ReviewSummary> getProviderReviewSummary(String providerId) async {
    final documents = await _getAllPages(
      _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true),
    );
    return calculateReviewSummary(documents.map(ServiceReview.fromDocument));
  }

  Future<ProviderDashboardStats> getProviderDashboardStats(
    String providerId,
  ) async {
    final results = await Future.wait([
      _getAllPages(
        _firestore
            .collection('bookings')
            .where('providerId', isEqualTo: providerId)
            .orderBy('createdAt', descending: true),
      ),
      _getAllPages(
        _firestore
            .collection('services')
            .where('providerId', isEqualTo: providerId)
            .orderBy('updatedAt', descending: true),
      ),
    ]);
    return calculateProviderDashboardStats(
      bookings: results[0].map(Booking.fromDocument),
      services: results[1].map(ServiceListing.fromDocument),
    );
  }

  Stream<List<BlockedUser>> watchBlockedUsers(String uid, {int limit = 50}) =>
      _firestore
          .collection('blocks')
          .doc(uid)
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(limit.clamp(1, 100))
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(BlockedUser.fromDocument)
                .toList(growable: false),
          );

  Stream<DeletionRequest?> watchDeletionRequest(String uid) => _firestore
      .collection('deletion_requests')
      .doc(uid)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? DeletionRequest.fromDocument(snapshot) : null,
      );

  Stream<List<FixMateNotification>> watchActivity({
    required String uid,
    required UserRole role,
  }) => watchBookings(uid: uid, role: role).map((bookings) {
    final activity = bookings.map((booking) {
      final hasIncomingMessage =
          booking.lastMessageSenderId != null &&
          booking.lastMessageSenderId != uid &&
          booking.lastMessageAt != null;
      final title = hasIncomingMessage
          ? 'Message from ${role == UserRole.customer ? booking.providerName : booking.customerName}'
          : _bookingActivityTitle(booking.status);
      final body = hasIncomingMessage
          ? booking.lastMessagePreview ??
                'Open the booking to view the message.'
          : '${booking.serviceTitle} • ${booking.scheduleDateKey}';
      return FixMateNotification(
        id: booking.id,
        title: title,
        body: body,
        type: hasIncomingMessage
            ? NotificationType.message
            : NotificationType.booking,
        route: '/booking/${booking.id}',
        createdAt:
            booking.lastMessageAt ?? booking.updatedAt ?? booking.createdAt,
      );
    }).toList();
    activity.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return activity;
  });

  Stream<ActivityFeed> watchActivityFeed({
    required String uid,
    required UserRole role,
  }) {
    late final StreamController<ActivityFeed> controller;
    StreamSubscription<List<FixMateNotification>>? activitySubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    stateSubscription;
    var items = const <FixMateNotification>[];
    DateTime? lastReadAt;
    var activityReady = false;
    var stateReady = false;
    var readTrackingAvailable = true;

    void emit() {
      if (!controller.isClosed && activityReady && stateReady) {
        controller.add(
          ActivityFeed(
            items: items,
            lastReadAt: lastReadAt,
            readTrackingAvailable: readTrackingAvailable,
          ),
        );
      }
    }

    controller = StreamController<ActivityFeed>(
      onListen: () {
        activitySubscription = watchActivity(uid: uid, role: role).listen((
          value,
        ) {
          items = value;
          activityReady = true;
          emit();
        }, onError: controller.addError);
        stateSubscription = _firestore
            .collection('activity_states')
            .doc(uid)
            .snapshots()
            .listen(
              (snapshot) {
                readTrackingAvailable = true;
                lastReadAt = snapshot.exists
                    ? dateFrom(snapshot.data()?['lastReadAt'])
                    : null;
                stateReady = true;
                emit();
              },
              onError: (Object error, StackTrace stack) {
                if (error is FirebaseException &&
                    error.code == 'permission-denied') {
                  readTrackingAvailable = false;
                  lastReadAt = null;
                  stateReady = true;
                  emit();
                  return;
                }
                controller.addError(error, stack);
              },
            );
      },
      onCancel: () async {
        await activitySubscription?.cancel();
        await stateSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchQueryWithServerStart(
    Query<Map<String, dynamic>> query,
  ) async* {
    final initial = await query
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    yield initial;
    yield* query.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchDocumentWithServerStart(
    DocumentReference<Map<String, dynamic>> document,
  ) async* {
    final initial = await document
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    yield initial;
    yield* document.snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getAllPages(
    Query<Map<String, dynamic>> query, {
    int pageSize = 100,
  }) async {
    final documents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Query<Map<String, dynamic>> page = query.limit(pageSize);
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Firebase data loading timed out.');
      }
      final snapshot = await page
          .get(const GetOptions(source: Source.server))
          .timeout(remaining);
      documents.addAll(snapshot.docs);
      if (snapshot.docs.length < pageSize) return documents;
      page = query.startAfterDocument(snapshot.docs.last).limit(pageSize);
    }
  }

  Future<void> markAllActivityRead(String uid) async {
    final user = _requireAuthUser();
    if (user.uid != uid) throw StateError('You can update only your activity.');
    await _firestore.collection('activity_states').doc(uid).set({
      'uid': uid,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _bookingActivityTitle(BookingStatus status) => switch (status) {
    BookingStatus.pending => 'Booking requested',
    BookingStatus.accepted => 'Booking accepted',
    BookingStatus.rejected => 'Booking rejected',
    BookingStatus.cancelled => 'Booking cancelled',
    BookingStatus.inProgress => 'Work started',
    BookingStatus.completionRequested => 'Completion requested',
    BookingStatus.completed => 'Booking completed',
    BookingStatus.disputed => 'Booking disputed',
  };

  Future<Map<String, dynamic>> runMutation(
    String name,
    Map<String, dynamic> data,
  ) => switch (name) {
    'createBooking' => _createBooking(data),
    'respondToBooking' => _respondToBooking(data),
    'startBooking' => _transitionBooking(
      data,
      expected: BookingStatus.accepted,
      next: BookingStatus.inProgress,
      actor: UserRole.provider,
    ),
    'requestCompletion' => _transitionBooking(
      data,
      expected: BookingStatus.inProgress,
      next: BookingStatus.completionRequested,
      actor: UserRole.provider,
    ),
    'confirmCompletion' => _transitionBooking(
      data,
      expected: BookingStatus.completionRequested,
      next: BookingStatus.completed,
      actor: UserRole.customer,
    ),
    'disputeCompletion' => _disputeCompletion(data),
    'cancelBooking' => _cancelBooking(data),
    'checkCommunication' => _checkCommunication(data),
    'sendMessage' => _sendMessage(data),
    'submitReview' => _submitReview(data),
    'submitReport' => _submitReport(data),
    'setUserBlocked' => _setUserBlocked(data),
    'requestAccountDeletion' => _requestAccountDeletion(),
    _ => Future<Map<String, dynamic>>.error(
      ArgumentError('Unsupported marketplace action: $name'),
    ),
  };

  User _requireAuthUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to continue.');
    if (!user.emailVerified) throw StateError('Verify your email first.');
    return user;
  }

  Future<Map<String, dynamic>> _createBooking(
    Map<String, dynamic> input,
  ) async {
    final authUser = _requireAuthUser();
    final serviceId = _requiredString(input, 'serviceId');
    final dateKey = _requiredString(input, 'dateKey');
    final timeWindow = _enumValue(
      TimeWindow.values,
      _requiredString(input, 'timeWindow'),
      'time window',
    );
    final areaKey = _requiredString(input, 'serviceAreaKey');
    final address = _requiredString(input, 'address');
    final landmark = (input['landmark'] as String? ?? '').trim();
    final notes = (input['notes'] as String? ?? '').trim();
    if (address.length < 5 || address.length > 500) {
      throw ArgumentError('Enter a complete address of up to 500 characters.');
    }
    if (landmark.length > 200 || notes.length > 500) {
      throw ArgumentError('Landmark or notes are too long.');
    }
    final scheduledStart = _scheduledStart(dateKey, timeWindow);
    if (!scheduledStart.isAfter(DateTime.now().toUtc())) {
      throw ArgumentError('Choose a future service date.');
    }

    final bookingRef = _firestore.collection('bookings').doc();
    final eventRef = bookingRef.collection('events').doc();
    final contactRef = bookingRef.collection('private').doc('contact');
    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(authUser.uid);
      final serviceRef = _firestore.collection('services').doc(serviceId);
      final userSnapshot = await transaction.get(userRef);
      final serviceSnapshot = await transaction.get(serviceRef);
      if (!userSnapshot.exists || !serviceSnapshot.exists) {
        throw StateError('The account or service is no longer available.');
      }
      final user = userSnapshot.data()!;
      final service = serviceSnapshot.data()!;
      if (user['role'] != UserRole.customer.name ||
          user['status'] != AccountStatus.active.name) {
        throw StateError('An active customer account is required.');
      }
      if (service['status'] != ServiceStatus.active.name) {
        throw StateError('This service is not active.');
      }
      final providerId = service['providerId'] as String? ?? '';
      final providerRef = _firestore
          .collection('provider_profiles')
          .doc(providerId);
      final outgoingBlockRef = _firestore
          .collection('blocks')
          .doc(authUser.uid)
          .collection('users')
          .doc(providerId);
      final incomingBlockRef = _firestore
          .collection('blocks')
          .doc(providerId)
          .collection('users')
          .doc(authUser.uid);
      final providerSnapshot = await transaction.get(providerRef);
      final outgoingBlock = await transaction.get(outgoingBlockRef);
      final incomingBlock = await transaction.get(incomingBlockRef);
      if (!providerSnapshot.exists ||
          !ProviderProfile.fromDocument(providerSnapshot).isBookable) {
        throw StateError('This provider is not currently approved.');
      }
      if (outgoingBlock.exists || incomingBlock.exists) {
        throw StateError(
          'A booking cannot be created while either participant is blocked.',
        );
      }
      final provider = providerSnapshot.data()!;
      final areaKeys = List<String>.from(
        service['areaKeys'] as List<dynamic>? ?? const [],
      );
      final areaLabels = List<String>.from(
        service['areaLabels'] as List<dynamic>? ?? const [],
      );
      final areaIndex = areaKeys.indexOf(areaKey);
      if (areaIndex < 0) {
        throw ArgumentError('The provider does not cover that service area.');
      }
      final priceBdt = (service['priceBdt'] as num?)?.toInt() ?? 0;
      if (priceBdt <= 0) throw StateError('The service price is invalid.');
      final booking = <String, dynamic>{
        'customerId': authUser.uid,
        'providerId': providerId,
        'serviceId': serviceId,
        'customerName': user['displayName'],
        'providerName': service['providerName'] ?? provider['publicName'],
        'serviceTitle': service['title'],
        'scheduleDateKey': dateKey,
        'scheduledStart': Timestamp.fromDate(scheduledStart),
        'timeWindow': timeWindow.name,
        'divisionCode': provider['divisionCode'],
        'districtCode': service['districtCode'],
        'areaLabel': areaLabels[areaIndex],
        'areaKey': areaKey,
        'priceBdt': priceBdt,
        'status': BookingStatus.pending.name,
        'paymentStatus': PaymentStatus.unpaid.name,
        'notes': notes,
        'contactReleasedAt': null,
        'cancellation': null,
        'rejection': null,
        'dispute': null,
        'completedAt': null,
        'lastEventId': eventRef.id,
        'lastMessageId': null,
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'lastMessagePreview': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(bookingRef, booking);
      transaction.set(contactRef, <String, dynamic>{
        'customerPhone': user['phoneE164'],
        'providerPhone': '',
        'address': address,
        'landmark': landmark,
      });
      transaction.set(eventRef, <String, dynamic>{
        'type': BookingStatus.pending.name,
        'actorId': authUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingRef.id, BookingStatus.pending.name);
  }

  Future<Map<String, dynamic>> _respondToBooking(
    Map<String, dynamic> input,
  ) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final decision = _requiredString(input, 'decision');
    if (decision != 'accept' && decision != 'reject') {
      throw ArgumentError('Choose accept or reject.');
    }
    final reason = (input['reason'] as String? ?? '').trim();
    if (decision == 'reject' && reason.isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final contactRef = bookingRef.collection('private').doc('contact');
    final eventRef = bookingRef.collection('events').doc();
    final next = decision == 'accept'
        ? BookingStatus.accepted
        : BookingStatus.rejected;
    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final userRef = _firestore.collection('users').doc(user.uid);
      final providerProfileRef = _firestore
          .collection('provider_profiles')
          .doc(user.uid);
      final userSnapshot = await transaction.get(userRef);
      final providerProfileSnapshot = await transaction.get(providerProfileRef);
      if (!bookingSnapshot.exists ||
          !userSnapshot.exists ||
          !providerProfileSnapshot.exists) {
        throw StateError('The booking or provider account is unavailable.');
      }
      if (userSnapshot.data()?['status'] != AccountStatus.active.name ||
          !ProviderProfile.fromDocument(providerProfileSnapshot).isBookable) {
        throw StateError('Your provider account is not currently eligible.');
      }
      final booking = bookingSnapshot.data()!;
      if (booking['providerId'] != user.uid ||
          booking['status'] != BookingStatus.pending.name) {
        throw StateError('This booking is no longer available to accept.');
      }
      DocumentReference<Map<String, dynamic>>? slotRef;
      if (next == BookingStatus.accepted) {
        slotRef = _slotReference(booking);
        final slotSnapshot = await transaction.get(slotRef);
        if (slotSnapshot.exists &&
            slotSnapshot.data()?['bookingId'] != bookingId) {
          throw StateError('You already have a booking in this time window.');
        }
      }
      transaction.update(bookingRef, <String, dynamic>{
        'status': next.name,
        'lastEventId': eventRef.id,
        if (next == BookingStatus.accepted)
          'contactReleasedAt': FieldValue.serverTimestamp()
        else
          'rejection': <String, dynamic>{
            'reason': reason,
            'actorId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (next == BookingStatus.accepted) {
        transaction.update(contactRef, <String, dynamic>{
          'providerPhone': userSnapshot.data()!['phoneE164'],
        });
        transaction.set(slotRef!, <String, dynamic>{
          'providerId': user.uid,
          'bookingId': bookingId,
          'scheduleDateKey': booking['scheduleDateKey'],
          'timeWindow': booking['timeWindow'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(eventRef, <String, dynamic>{
        'type': next.name,
        'actorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingId, next.name);
  }

  Future<Map<String, dynamic>> _transitionBooking(
    Map<String, dynamic> input, {
    required BookingStatus expected,
    required BookingStatus next,
    required UserRole actor,
  }) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final eventRef = bookingRef.collection('events').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final actorSnapshot = await transaction.get(
        _firestore.collection('users').doc(user.uid),
      );
      if (!snapshot.exists) throw StateError('Booking not found.');
      if (!actorSnapshot.exists ||
          actorSnapshot.data()?['status'] != AccountStatus.active.name) {
        throw StateError('Your account is not active.');
      }
      final booking = snapshot.data()!;
      final actorField = actor == UserRole.customer
          ? 'customerId'
          : 'providerId';
      if (booking[actorField] != user.uid ||
          booking['status'] != expected.name) {
        throw StateError('This booking cannot perform that transition.');
      }
      if (actor == UserRole.provider) {
        final profileSnapshot = await transaction.get(
          _firestore.collection('provider_profiles').doc(user.uid),
        );
        if (!profileSnapshot.exists ||
            !ProviderProfile.fromDocument(profileSnapshot).isBookable) {
          throw StateError('Your provider account is not currently eligible.');
        }
      }
      transaction.update(bookingRef, <String, dynamic>{
        'status': next.name,
        'lastEventId': eventRef.id,
        if (next == BookingStatus.completed) ...<String, dynamic>{
          'paymentStatus': PaymentStatus.paidCash.name,
          'completedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (next == BookingStatus.completed) {
        transaction.delete(_slotReference(booking));
      }
      transaction.set(eventRef, <String, dynamic>{
        'type': next.name,
        'actorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingId, next.name);
  }

  Future<Map<String, dynamic>> _disputeCompletion(
    Map<String, dynamic> input,
  ) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final reason = _requiredString(input, 'reason');
    final details = _requiredString(input, 'details');
    if (details.length > 1000) throw ArgumentError('Details are too long.');
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final eventRef = bookingRef.collection('events').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      if (!snapshot.exists) throw StateError('Booking not found.');
      final booking = snapshot.data()!;
      if (booking['customerId'] != user.uid ||
          booking['status'] != BookingStatus.completionRequested.name) {
        throw StateError('Completion is not awaiting your confirmation.');
      }
      transaction.update(bookingRef, <String, dynamic>{
        'status': BookingStatus.disputed.name,
        'paymentStatus': PaymentStatus.disputed.name,
        'dispute': <String, dynamic>{
          'reason': reason,
          'details': details,
          'actorId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
        'lastEventId': eventRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(_slotReference(booking));
      transaction.set(eventRef, <String, dynamic>{
        'type': BookingStatus.disputed.name,
        'actorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingId, BookingStatus.disputed.name);
  }

  Future<Map<String, dynamic>> _cancelBooking(
    Map<String, dynamic> input,
  ) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final reason = _requiredString(input, 'reason');
    final details = (input['details'] as String? ?? '').trim();
    if (details.length > 1000) throw ArgumentError('Details are too long.');
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final eventRef = bookingRef.collection('events').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      if (!snapshot.exists) throw StateError('Booking not found.');
      final booking = snapshot.data()!;
      if (booking['customerId'] != user.uid &&
          booking['providerId'] != user.uid) {
        throw StateError('You are not a participant in this booking.');
      }
      final current = booking['status'];
      if (current != BookingStatus.pending.name &&
          current != BookingStatus.accepted.name) {
        throw StateError('Only pending or accepted bookings can be cancelled.');
      }
      transaction.update(bookingRef, <String, dynamic>{
        'status': BookingStatus.cancelled.name,
        'cancellation': <String, dynamic>{
          'reason': reason,
          'details': details,
          'actorId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
        'lastEventId': eventRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (current == BookingStatus.accepted.name) {
        transaction.delete(_slotReference(booking));
      }
      transaction.set(eventRef, <String, dynamic>{
        'type': BookingStatus.cancelled.name,
        'actorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingId, BookingStatus.cancelled.name);
  }

  Future<Map<String, dynamic>> _checkCommunication(
    Map<String, dynamic> input,
  ) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final booking = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!booking.exists) throw StateError('Booking not found.');
    final data = booking.data()!;
    if (data['customerId'] != user.uid && data['providerId'] != user.uid) {
      throw StateError('You are not a participant in this booking.');
    }
    if (data['contactReleasedAt'] == null) {
      throw StateError('Contact details are not available yet.');
    }
    final otherUid = data['customerId'] == user.uid
        ? data['providerId'] as String
        : data['customerId'] as String;
    final results = await Future.wait([
      _firestore.collection('users').doc(user.uid).get(),
      _firestore
          .collection('blocks')
          .doc(user.uid)
          .collection('users')
          .doc(otherUid)
          .get(),
      _firestore
          .collection('blocks')
          .doc(otherUid)
          .collection('users')
          .doc(user.uid)
          .get(),
    ]);
    if (!results.first.exists ||
        results.first.data()?['status'] != AccountStatus.active.name) {
      return _result(bookingId, 'unavailable');
    }
    return _result(
      bookingId,
      results.skip(1).any((snapshot) => snapshot.exists)
          ? 'blocked'
          : 'allowed',
    );
  }

  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> input) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final text = _requiredString(input, 'text');
    if (text.length > 1000) {
      throw ArgumentError('Messages are limited to 1,000 characters.');
    }
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final bookingSnapshot = await bookingRef.get();
    if (!bookingSnapshot.exists) throw StateError('Booking not found.');
    final booking = bookingSnapshot.data()!;
    if (booking['customerId'] != user.uid &&
        booking['providerId'] != user.uid) {
      throw StateError('You are not a participant in this booking.');
    }
    if (!<String>{
      BookingStatus.accepted.name,
      BookingStatus.inProgress.name,
      BookingStatus.completionRequested.name,
    }.contains(booking['status'])) {
      throw StateError('Chat is not open for this booking.');
    }
    final otherUid = booking['customerId'] == user.uid
        ? booking['providerId'] as String
        : booking['customerId'] as String;
    final blocks = await Future.wait([
      _firestore.collection('users').doc(user.uid).get(),
      _firestore
          .collection('blocks')
          .doc(user.uid)
          .collection('users')
          .doc(otherUid)
          .get(),
      _firestore
          .collection('blocks')
          .doc(otherUid)
          .collection('users')
          .doc(user.uid)
          .get(),
    ]);
    if (!blocks.first.exists ||
        blocks.first.data()?['status'] != AccountStatus.active.name) {
      throw StateError('Your account is not active.');
    }
    if (blocks.skip(1).any((snapshot) => snapshot.exists)) {
      throw StateError(
        'Messaging is unavailable because one participant blocked the other.',
      );
    }
    final messageRef = bookingRef.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, <String, dynamic>{
      'senderId': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    batch.update(bookingRef, <String, dynamic>{
      'lastMessageId': messageRef.id,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': user.uid,
      'lastMessagePreview': text.length <= 120
          ? text
          : '${text.substring(0, 117)}…',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return _result(messageRef.id, 'sent');
  }

  Future<Map<String, dynamic>> _submitReview(Map<String, dynamic> input) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final rating = (input['rating'] as num?)?.toInt();
    final comment = (input['comment'] as String? ?? '').trim();
    if (rating == null || rating < 1 || rating > 5 || comment.length > 500) {
      throw ArgumentError('Enter a rating from 1 to 5 and a shorter comment.');
    }
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final reviewRef = _firestore.collection('reviews').doc(bookingId);
    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final reviewSnapshot = await transaction.get(reviewRef);
      if (!bookingSnapshot.exists) throw StateError('Booking not found.');
      final booking = bookingSnapshot.data()!;
      if (booking['customerId'] != user.uid ||
          booking['status'] != BookingStatus.completed.name) {
        throw StateError('Only the customer can review a completed booking.');
      }
      if (reviewSnapshot.exists) {
        throw StateError('This booking already has a review.');
      }
      transaction.set(reviewRef, <String, dynamic>{
        'bookingId': bookingId,
        'customerId': user.uid,
        'customerName': booking['customerName'],
        'providerId': booking['providerId'],
        'serviceId': booking['serviceId'],
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(bookingId, 'published');
  }

  Future<Map<String, dynamic>> _submitReport(Map<String, dynamic> input) async {
    final user = _requireAuthUser();
    final bookingId = _requiredString(input, 'bookingId');
    final targetType = _requiredString(input, 'targetType');
    final targetId = _requiredString(input, 'targetId');
    final reason = _requiredString(input, 'reason');
    final details = (input['details'] as String? ?? '').trim();
    final target = _enumValue(ReportTarget.values, targetType, 'report target');
    if (!MarketplacePolicies.isValidReport(
      target: target,
      reason: reason,
      details: details,
    )) {
      throw ArgumentError('The report details are invalid.');
    }
    final booking = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!booking.exists) throw StateError('Booking not found.');
    final bookingData = booking.data()!;
    if (bookingData['customerId'] != user.uid &&
        bookingData['providerId'] != user.uid) {
      throw StateError('You are not a participant in this booking.');
    }
    final otherUid = bookingData['customerId'] == user.uid
        ? bookingData['providerId'] as String
        : bookingData['customerId'] as String;
    if (targetType == ReportTarget.user.name && targetId != otherUid) {
      throw ArgumentError(
        'Only the other booking participant can be reported.',
      );
    }
    if (targetType == ReportTarget.message.name) {
      final message = await booking.reference
          .collection('messages')
          .doc(targetId)
          .get();
      if (!message.exists || message.data()?['senderId'] != otherUid) {
        throw ArgumentError('The reported message is invalid.');
      }
    }
    final reportId = MarketplacePolicies.reportDocumentId(
      reporterId: user.uid,
      bookingId: bookingId,
      target: target,
      targetId: targetId,
    );
    final reference = _firestore.collection('reports').doc(reportId);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        throw StateError('You have already reported this item.');
      }
      transaction.set(reference, <String, dynamic>{
        'reporterId': user.uid,
        'targetType': targetType,
        'targetId': targetId,
        'targetUserId': otherUid,
        'bookingId': bookingId,
        'reason': reason,
        'details': details,
        'status': ReportStatus.open.name,
        'moderationNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(reference.id, ReportStatus.open.name);
  }

  Future<Map<String, dynamic>> _setUserBlocked(
    Map<String, dynamic> input,
  ) async {
    final user = _requireAuthUser();
    final targetUid = _requiredString(input, 'targetUid');
    final blocked = input['blocked'] as bool? ?? false;
    if (targetUid == user.uid) {
      throw ArgumentError('You cannot block yourself.');
    }
    final reference = _firestore
        .collection('blocks')
        .doc(user.uid)
        .collection('users')
        .doc(targetUid);
    if (blocked) {
      final bookingId = _requiredString(input, 'bookingId');
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      await _firestore.runTransaction((transaction) async {
        final bookingSnapshot = await transaction.get(bookingRef);
        if (!bookingSnapshot.exists) throw StateError('Booking not found.');
        final booking = bookingSnapshot.data()!;
        if (booking['customerId'] != user.uid &&
            booking['providerId'] != user.uid) {
          throw StateError('You are not a participant in this booking.');
        }
        final otherUid = booking['customerId'] == user.uid
            ? booking['providerId'] as String
            : booking['customerId'] as String;
        if (otherUid != targetUid) {
          throw ArgumentError('Only the other participant can be blocked.');
        }
        final displayName = booking['customerId'] == targetUid
            ? booking['customerName'] as String? ?? 'FixMate user'
            : booking['providerName'] as String? ?? 'FixMate user';
        transaction.set(reference, <String, dynamic>{
          'blockedUid': targetUid,
          'displayNameSnapshot': displayName,
          'bookingId': bookingId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await reference.delete();
    }
    return _result(targetUid, blocked ? 'blocked' : 'unblocked');
  }

  Future<Map<String, dynamic>> _requestAccountDeletion() async {
    final user = _requireAuthUser();
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn).abs() >
            const Duration(minutes: 10)) {
      throw StateError(
        'For security, sign out and sign in again before requesting deletion.',
      );
    }
    const blocking = <String>[
      'pending',
      'accepted',
      'inProgress',
      'completionRequested',
      'disputed',
    ];
    final customerBlocking = await _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: user.uid)
        .where('status', whereIn: blocking)
        .limit(1)
        .get();
    final providerBlocking = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: user.uid)
        .where('status', whereIn: blocking)
        .limit(1)
        .get();
    if (customerBlocking.docs.isNotEmpty || providerBlocking.docs.isNotEmpty) {
      throw StateError(
        'Cancel pending or accepted bookings and resolve active or disputed bookings before deleting your account.',
      );
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final requestRef = _firestore.collection('deletion_requests').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final requestSnapshot = await transaction.get(requestRef);
      if (!userSnapshot.exists) throw StateError('Account profile not found.');
      if (requestSnapshot.exists) return;
      final currentStatus = userSnapshot.data()?['status'];
      if (currentStatus != AccountStatus.active.name &&
          currentStatus != AccountStatus.deletionPending.name) {
        throw StateError('This account cannot request deletion.');
      }
      if (currentStatus == AccountStatus.active.name) {
        transaction.update(userRef, <String, dynamic>{
          'status': AccountStatus.deletionPending.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(requestRef, <String, dynamic>{
        'uid': user.uid,
        'status': DeletionRequestStatus.requested.name,
        'failureMessage': '',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return _result(user.uid, DeletionRequestStatus.requested.name);
  }

  DocumentReference<Map<String, dynamic>> _slotReference(
    Map<String, dynamic> booking,
  ) => _firestore
      .collection('provider_slots')
      .doc(
        '${booking['providerId']}_${booking['scheduleDateKey']}_${booking['timeWindow']}',
      );

  DateTime _scheduledStart(String dateKey, TimeWindow window) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey)) {
      throw ArgumentError('Choose a valid service date.');
    }
    final hour = switch (window) {
      TimeWindow.morning => 8,
      TimeWindow.afternoon => 12,
      TimeWindow.evening => 16,
    };
    final hourText = hour.toString().padLeft(2, '0');
    try {
      return DateTime.parse('${dateKey}T$hourText:00:00+06:00').toUtc();
    } on FormatException {
      throw ArgumentError('Choose a valid service date.');
    }
  }

  String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw ArgumentError('Missing required value: $key.');
    }
    return value.trim();
  }

  T _enumValue<T extends Enum>(List<T> values, String raw, String label) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw ArgumentError('Choose a valid $label.');
  }

  Map<String, dynamic> _result(String id, String status) => <String, dynamic>{
    'ok': true,
    'id': id,
    'status': status,
  };

  List<String> _normalizedLabels(List<String> values) {
    final labelsByKey = <String, String>{};
    for (final value in values) {
      final label = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = Validators.normalizeKey(label);
      if (label.isNotEmpty && key.isNotEmpty) labelsByKey[key] = label;
    }
    final entries = labelsByKey.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => entry.value).toList(growable: false);
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

ReviewSummary calculateReviewSummary(Iterable<ServiceReview> reviews) {
  var count = 0;
  var ratingTotal = 0;
  for (final review in reviews) {
    if (review.rating < 1 || review.rating > 5) continue;
    count++;
    ratingTotal += review.rating;
  }
  return ReviewSummary(
    count: count,
    average: count == 0 ? null : ratingTotal / count,
  );
}

ProviderDashboardStats calculateProviderDashboardStats({
  required Iterable<Booking> bookings,
  required Iterable<ServiceListing> services,
}) {
  var pending = 0;
  var active = 0;
  var completed = 0;
  var cashEarningsBdt = 0;
  for (final booking in bookings) {
    switch (booking.status) {
      case BookingStatus.pending:
        pending++;
      case BookingStatus.accepted:
      case BookingStatus.inProgress:
      case BookingStatus.completionRequested:
        active++;
      case BookingStatus.completed:
        completed++;
        if (booking.paymentStatus == PaymentStatus.paidCash) {
          cashEarningsBdt += booking.priceBdt;
        }
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
      case BookingStatus.disputed:
        break;
    }
  }
  var totalServices = 0;
  var activeServices = 0;
  for (final service in services) {
    totalServices++;
    if (service.status == ServiceStatus.active) activeServices++;
  }
  return ProviderDashboardStats(
    pending: pending,
    active: active,
    completed: completed,
    totalServices: totalServices,
    activeServices: activeServices,
    cashEarningsBdt: cashEarningsBdt,
  );
}
