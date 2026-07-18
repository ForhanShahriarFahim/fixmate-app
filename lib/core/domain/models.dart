import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, provider }

enum AccountStatus { active, suspended, deletionPending, deleted }

enum ProviderApprovalStatus { pending, approved, rejected }

enum ServiceStatus { active, archived }

enum BookingStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  inProgress,
  completionRequested,
  completed,
  disputed,
}

enum TimeWindow { morning, afternoon, evening }

enum PaymentStatus { unpaid, paidCash, disputed }

enum ReportTarget { user, message }

enum ReportStatus { open, reviewing, resolved, dismissed }

enum NotificationType { booking, message, review, moderation, account }

T enumFromName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final wire = raw?.toString();
  for (final value in values) {
    if (value.name == wire) return value;
  }
  return fallback;
}

DateTime? dateFrom(Object? value) => value is Timestamp ? value.toDate() : null;

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phoneE164,
    required this.role,
    required this.status,
    required this.photoPath,
    required this.termsVersion,
    required this.isAdultConfirmed,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return AppUserProfile(
      id: document.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneE164: data['phoneE164'] as String? ?? '',
      role: enumFromName(UserRole.values, data['role'], UserRole.customer),
      status: enumFromName(
        AccountStatus.values,
        data['status'],
        AccountStatus.active,
      ),
      photoPath: data['photoPath'] as String?,
      termsVersion: data['termsVersion'] as String? ?? '',
      isAdultConfirmed: data['isAdultConfirmed'] as bool? ?? false,
      createdAt: dateFrom(data['createdAt']),
      updatedAt: dateFrom(data['updatedAt']),
    );
  }

  final String id;
  final String displayName;
  final String email;
  final String phoneE164;
  final UserRole role;
  final AccountStatus status;
  final String? photoPath;
  final String termsVersion;
  final bool isAdultConfirmed;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ProviderProfile {
  const ProviderProfile({
    required this.providerId,
    required this.publicName,
    required this.avatarUrl,
    required this.bio,
    required this.experienceYears,
    required this.divisionCode,
    required this.districtCode,
    required this.serviceAreaLabels,
    required this.serviceAreaKeys,
    required this.approvalStatus,
    required this.ratingAverage,
    required this.reviewCount,
    required this.completedBookings,
  });

  factory ProviderProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ProviderProfile(
      providerId: data['providerId'] as String? ?? document.id,
      publicName: data['publicName'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      experienceYears: (data['experienceYears'] as num?)?.toInt() ?? 0,
      divisionCode: data['divisionCode'] as String? ?? '',
      districtCode: data['districtCode'] as String? ?? '',
      serviceAreaLabels: List<String>.from(
        data['serviceAreaLabels'] as List<dynamic>? ?? const [],
      ),
      serviceAreaKeys: List<String>.from(
        data['serviceAreaKeys'] as List<dynamic>? ?? const [],
      ),
      approvalStatus: enumFromName(
        ProviderApprovalStatus.values,
        data['approvalStatus'],
        ProviderApprovalStatus.pending,
      ),
      ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      completedBookings: (data['completedBookings'] as num?)?.toInt() ?? 0,
    );
  }

  final String providerId;
  final String publicName;
  final String? avatarUrl;
  final String bio;
  final int experienceYears;
  final String divisionCode;
  final String districtCode;
  final List<String> serviceAreaLabels;
  final List<String> serviceAreaKeys;
  final ProviderApprovalStatus approvalStatus;
  final double ratingAverage;
  final int reviewCount;
  final int completedBookings;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.order,
  });

  factory ServiceCategory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ServiceCategory(
      id: document.id,
      name: data['name'] as String? ?? '',
      iconKey: data['iconKey'] as String? ?? 'handyman',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String iconKey;
  final int order;
}

class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.priceBdt,
    required this.coverImageUrl,
    required this.districtCode,
    required this.areaLabels,
    required this.areaKeys,
    required this.status,
    required this.providerRating,
    required this.reviewCount,
  });

  factory ServiceListing.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ServiceListing(
      id: document.id,
      providerId: data['providerId'] as String? ?? '',
      providerName: data['providerName'] as String? ?? 'Service provider',
      categoryId: data['categoryId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priceBdt: (data['priceBdt'] as num?)?.toInt() ?? 0,
      coverImageUrl: data['coverImageUrl'] as String?,
      districtCode: data['districtCode'] as String? ?? '',
      areaLabels: List<String>.from(
        data['areaLabels'] as List<dynamic>? ?? const [],
      ),
      areaKeys: List<String>.from(
        data['areaKeys'] as List<dynamic>? ?? const [],
      ),
      status: enumFromName(
        ServiceStatus.values,
        data['status'],
        ServiceStatus.active,
      ),
      providerRating: (data['providerRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String providerId;
  final String providerName;
  final String categoryId;
  final String title;
  final String description;
  final int priceBdt;
  final String? coverImageUrl;
  final String districtCode;
  final List<String> areaLabels;
  final List<String> areaKeys;
  final ServiceStatus status;
  final double providerRating;
  final int reviewCount;
}

class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.customerName,
    required this.providerName,
    required this.serviceTitle,
    required this.scheduleDateKey,
    required this.timeWindow,
    required this.areaLabel,
    required this.areaKey,
    required this.priceBdt,
    required this.status,
    required this.paymentStatus,
    required this.notes,
    this.createdAt,
    this.updatedAt,
    this.contactReleasedAt,
    this.lastMessageId,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessagePreview,
  });

  factory Booking.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return Booking(
      id: document.id,
      customerId: data['customerId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      providerName: data['providerName'] as String? ?? 'Provider',
      serviceTitle: data['serviceTitle'] as String? ?? '',
      scheduleDateKey: data['scheduleDateKey'] as String? ?? '',
      timeWindow: enumFromName(
        TimeWindow.values,
        data['timeWindow'],
        TimeWindow.morning,
      ),
      areaLabel: data['areaLabel'] as String? ?? '',
      areaKey: data['areaKey'] as String? ?? '',
      priceBdt: (data['priceBdt'] as num?)?.toInt() ?? 0,
      status: enumFromName(
        BookingStatus.values,
        data['status'],
        BookingStatus.pending,
      ),
      paymentStatus: enumFromName(
        PaymentStatus.values,
        data['paymentStatus'],
        PaymentStatus.unpaid,
      ),
      notes: data['notes'] as String? ?? '',
      createdAt: dateFrom(data['createdAt']),
      updatedAt: dateFrom(data['updatedAt']),
      contactReleasedAt: dateFrom(data['contactReleasedAt']),
      lastMessageId: data['lastMessageId'] as String?,
      lastMessageAt: dateFrom(data['lastMessageAt']),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessagePreview: data['lastMessagePreview'] as String?,
    );
  }

  final String id;
  final String customerId;
  final String providerId;
  final String serviceId;
  final String customerName;
  final String providerName;
  final String serviceTitle;
  final String scheduleDateKey;
  final TimeWindow timeWindow;
  final String areaLabel;
  final String areaKey;
  final int priceBdt;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? contactReleasedAt;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessagePreview;

  bool get isTerminal => <BookingStatus>{
    BookingStatus.rejected,
    BookingStatus.cancelled,
    BookingStatus.completed,
    BookingStatus.disputed,
  }.contains(status);

  bool get canChat => <BookingStatus>{
    BookingStatus.accepted,
    BookingStatus.inProgress,
    BookingStatus.completionRequested,
  }.contains(status);
}

class BookingContact {
  const BookingContact({
    required this.customerPhone,
    required this.providerPhone,
    required this.address,
    required this.landmark,
  });

  factory BookingContact.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return BookingContact(
      customerPhone: data['customerPhone'] as String? ?? '',
      providerPhone: data['providerPhone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      landmark: data['landmark'] as String? ?? '',
    );
  }

  final String customerPhone;
  final String providerPhone;
  final String address;
  final String landmark;
}

class BookingEvent {
  const BookingEvent({
    required this.id,
    required this.type,
    required this.actorId,
    this.createdAt,
  });

  factory BookingEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return BookingEvent(
      id: document.id,
      type: data['type'] as String? ?? '',
      actorId: data['actorId'] as String? ?? 'system',
      createdAt: dateFrom(data['createdAt']),
    );
  }

  final String id;
  final String type;
  final String actorId;
  final DateTime? createdAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: dateFrom(data['createdAt']),
      readAt: dateFrom(data['readAt']),
    );
  }

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final DateTime? readAt;
}

class FixMateNotification {
  const FixMateNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.route,
    this.createdAt,
    this.readAt,
  });

  factory FixMateNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return FixMateNotification(
      id: document.id,
      title: data['title'] as String? ?? 'FixMate',
      body: data['body'] as String? ?? '',
      type: enumFromName(
        NotificationType.values,
        data['type'],
        NotificationType.account,
      ),
      route: data['route'] as String? ?? '/',
      createdAt: dateFrom(data['createdAt']),
      readAt: dateFrom(data['readAt']),
    );
  }

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String route;
  final DateTime? createdAt;
  final DateTime? readAt;
}

class ServiceReview {
  const ServiceReview({
    required this.bookingId,
    required this.providerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory ServiceReview.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ServiceReview(
      bookingId: document.id,
      providerId: data['providerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      createdAt: dateFrom(data['createdAt']),
    );
  }

  final String bookingId;
  final String providerId;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime? createdAt;
}
