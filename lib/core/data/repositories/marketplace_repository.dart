import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      'avatarUrl': null,
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
  }) async {
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
      'providerName': providerName.trim(),
      'categoryId': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'priceBdt': priceBdt,
      'coverImageUrl': null,
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
      .limit(100)
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
      final providerSnapshot = await transaction.get(providerRef);
      if (!providerSnapshot.exists ||
          providerSnapshot.data()?['approvalStatus'] !=
              ProviderApprovalStatus.approved.name) {
        throw StateError('This provider is not currently approved.');
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
      final userSnapshot = await transaction.get(userRef);
      if (!bookingSnapshot.exists || !userSnapshot.exists) {
        throw StateError('The booking or provider account is unavailable.');
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
      if (!snapshot.exists) throw StateError('Booking not found.');
      final booking = snapshot.data()!;
      final actorField = actor == UserRole.customer
          ? 'customerId'
          : 'providerId';
      if (booking[actorField] != user.uid ||
          booking['status'] != expected.name) {
        throw StateError('This booking cannot perform that transition.');
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
    return _result(
      bookingId,
      results.any((snapshot) => snapshot.exists) ? 'blocked' : 'allowed',
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
    if (blocks.any((snapshot) => snapshot.exists)) {
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
    if (!<String>{'user', 'message'}.contains(targetType) ||
        details.length > 1000) {
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
    final reference = _firestore.collection('reports').doc();
    await reference.set(<String, dynamic>{
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
      await reference.set(<String, dynamic>{
        'blockedUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.delete();
    }
    return _result(targetUid, blocked ? 'blocked' : 'unblocked');
  }

  Future<Map<String, dynamic>> _requestAccountDeletion() async {
    final user = _requireAuthUser();
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
    await userRef.update(<String, dynamic>{
      'status': AccountStatus.deletionPending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final customerBookings = await _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: user.uid)
        .get();
    final providerBookings = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: user.uid)
        .get();
    final allBookings = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final booking in customerBookings.docs) booking.id: booking,
      for (final booking in providerBookings.docs) booking.id: booking,
    };
    for (final booking in allBookings.values) {
      final data = booking.data();
      final messages = await booking.reference
          .collection('messages')
          .where('senderId', isEqualTo: user.uid)
          .get();
      await _deleteInChunks(
        messages.docs.map((item) => item.reference).toList(),
      );
      final batch = _firestore.batch();
      batch.update(booking.reference, <String, dynamic>{
        if (data['customerId'] == user.uid) 'customerName': 'Deleted user',
        if (data['providerId'] == user.uid) 'providerName': 'Deleted provider',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        booking.reference.collection('private').doc('contact'),
        <String, dynamic>{
          if (data['customerId'] == user.uid) ...<String, dynamic>{
            'customerPhone': '',
            'address': '',
            'landmark': '',
          },
          if (data['providerId'] == user.uid) 'providerPhone': '',
        },
      );
      await batch.commit();
    }

    final services = await _firestore
        .collection('services')
        .where('providerId', isEqualTo: user.uid)
        .get();
    final reviews = await _firestore
        .collection('reviews')
        .where('customerId', isEqualTo: user.uid)
        .get();
    final blocks = await _firestore
        .collection('blocks')
        .doc(user.uid)
        .collection('users')
        .get();
    await _deleteInChunks(<DocumentReference<Map<String, dynamic>>>[
      ...services.docs.map((item) => item.reference),
      ...reviews.docs.map((item) => item.reference),
      ...blocks.docs.map((item) => item.reference),
    ]);
    final providerProfile = _firestore
        .collection('provider_profiles')
        .doc(user.uid);
    if ((await providerProfile.get()).exists) await providerProfile.delete();

    await userRef.update(<String, dynamic>{
      'displayName': 'Deleted user',
      'email': '',
      'phoneE164': '',
      'photoPath': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await user.delete();
    return _result(user.uid, 'deleted');
  }

  Future<void> _deleteInChunks(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (var start = 0; start < references.length; start += 400) {
      final batch = _firestore.batch();
      for (final reference in references.skip(start).take(400)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
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
}
