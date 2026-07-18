import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/domain/models.dart';

Booking bookingWith(BookingStatus status) => Booking(
  id: 'booking',
  customerId: 'customer',
  providerId: 'provider',
  serviceId: 'service',
  customerName: 'Customer',
  providerName: 'Provider',
  serviceTitle: 'Electrical repair',
  scheduleDateKey: '2026-07-20',
  timeWindow: TimeWindow.morning,
  areaLabel: 'Dhanmondi',
  areaKey: 'dhanmondi',
  priceBdt: 1200,
  status: status,
  paymentStatus: PaymentStatus.unpaid,
  notes: '',
);

void main() {
  test('chat is writable only during accepted work states', () {
    expect(bookingWith(BookingStatus.pending).canChat, isFalse);
    expect(bookingWith(BookingStatus.accepted).canChat, isTrue);
    expect(bookingWith(BookingStatus.inProgress).canChat, isTrue);
    expect(bookingWith(BookingStatus.completionRequested).canChat, isTrue);
    expect(bookingWith(BookingStatus.completed).canChat, isFalse);
  });

  test(
    'completed, cancelled, rejected, and disputed bookings are terminal',
    () {
      for (final status in <BookingStatus>[
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
        BookingStatus.disputed,
      ]) {
        expect(bookingWith(status).isTerminal, isTrue);
      }
      expect(bookingWith(BookingStatus.inProgress).isTerminal, isFalse);
    },
  );
}
