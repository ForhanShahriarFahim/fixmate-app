import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/data/repositories/marketplace_repository.dart';
import 'package:fixmate/core/data/repositories/marketplace_policies.dart';
import 'package:fixmate/core/domain/models.dart';

void main() {
  test('report validation is contextual and requires useful other details', () {
    expect(
      MarketplacePolicies.isValidReport(
        target: ReportTarget.user,
        reason: 'unsafe_behavior',
        details: '',
      ),
      isTrue,
    );
    expect(
      MarketplacePolicies.isValidReport(
        target: ReportTarget.message,
        reason: 'unsafe_behavior',
        details: '',
      ),
      isFalse,
    );
    expect(
      MarketplacePolicies.isValidReport(
        target: ReportTarget.message,
        reason: 'other',
        details: 'no',
      ),
      isFalse,
    );
  });

  test('report IDs are deterministic for duplicate prevention', () {
    final first = MarketplacePolicies.reportDocumentId(
      reporterId: 'customer',
      bookingId: 'booking',
      target: ReportTarget.message,
      targetId: 'message',
    );
    final second = MarketplacePolicies.reportDocumentId(
      reporterId: 'customer',
      bookingId: 'booking',
      target: ReportTarget.message,
      targetId: 'message',
    );
    expect(first, second);
    expect(first, 'customer_booking_message_message');
  });

  test(
    'activity feed retains completed bookings and calculates unread state',
    () {
      final readAt = DateTime.utc(2026, 8, 6, 9);
      final completed = FixMateNotification(
        id: 'completed-booking',
        title: 'Booking completed',
        body: 'Electrical repair',
        type: NotificationType.booking,
        route: '/booking/completed-booking',
        createdAt: readAt.add(const Duration(minutes: 1)),
      );
      final older = FixMateNotification(
        id: 'older-booking',
        title: 'Booking accepted',
        body: 'Plumbing',
        type: NotificationType.booking,
        route: '/booking/older-booking',
        createdAt: readAt.subtract(const Duration(minutes: 1)),
      );
      final feed = ActivityFeed(items: [completed, older], lastReadAt: readAt);
      expect(feed.items.map((item) => item.id), contains('completed-booking'));
      expect(feed.isUnread(completed), isTrue);
      expect(feed.isUnread(older), isFalse);
      expect(feed.unreadCount, 1);
    },
  );

  test('activity remains readable when unread tracking is unavailable', () {
    final item = FixMateNotification(
      id: 'booking',
      title: 'Booking completed',
      body: 'Electrical repair',
      type: NotificationType.booking,
      route: '/booking/booking',
      createdAt: DateTime.utc(2026, 8, 6),
    );
    final feed = ActivityFeed(
      items: [item],
      lastReadAt: null,
      readTrackingAvailable: false,
    );
    expect(feed.items, hasLength(1));
    expect(feed.unreadCount, 0);
    expect(feed.isUnread(item), isFalse);
  });

  test('review summary ignores malformed ratings and remains exact', () {
    final summary = calculateReviewSummary(const [
      ServiceReview(
        bookingId: 'one',
        providerId: 'provider',
        customerName: 'One',
        rating: 5,
        comment: 'Excellent',
      ),
      ServiceReview(
        bookingId: 'two',
        providerId: 'provider',
        customerName: 'Two',
        rating: 3,
        comment: 'Good',
      ),
      ServiceReview(
        bookingId: 'invalid',
        providerId: 'provider',
        customerName: 'Invalid',
        rating: 0,
        comment: '',
      ),
    ]);
    expect(summary.count, 2);
    expect(summary.average, 4);
  });

  test('provider dashboard counts only confirmed cash as earnings', () {
    Booking booking(
      String id,
      BookingStatus status, {
      PaymentStatus payment = PaymentStatus.unpaid,
      int price = 1000,
    }) => Booking(
      id: id,
      customerId: 'customer',
      providerId: 'provider',
      serviceId: 'service',
      customerName: 'Customer',
      providerName: 'Provider',
      serviceTitle: 'Repair',
      scheduleDateKey: '2026-08-07',
      timeWindow: TimeWindow.morning,
      areaLabel: 'Dhanmondi',
      areaKey: 'dhanmondi',
      priceBdt: price,
      status: status,
      paymentStatus: payment,
      notes: '',
    );

    ServiceListing service(String id, ServiceStatus status) => ServiceListing(
      id: id,
      providerId: 'provider',
      providerName: 'Provider',
      categoryId: 'electrical',
      title: 'Repair',
      description: 'Description',
      priceBdt: 1000,
      coverImageUrl: null,
      districtCode: 'dhaka',
      areaLabels: const ['Dhanmondi'],
      areaKeys: const ['dhanmondi'],
      status: status,
    );

    final stats = calculateProviderDashboardStats(
      bookings: [
        booking('pending', BookingStatus.pending),
        booking('active', BookingStatus.inProgress),
        booking(
          'paid',
          BookingStatus.completed,
          payment: PaymentStatus.paidCash,
          price: 1500,
        ),
        booking('unconfirmed', BookingStatus.completed, price: 3000),
      ],
      services: [
        service('active', ServiceStatus.active),
        service('archived', ServiceStatus.archived),
      ],
    );
    expect(stats.pending, 1);
    expect(stats.active, 1);
    expect(stats.completed, 2);
    expect(stats.cashEarningsBdt, 1500);
    expect(stats.totalServices, 2);
    expect(stats.activeServices, 1);
  });
}
