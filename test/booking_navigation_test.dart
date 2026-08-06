import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/features/bookings/booking_screens.dart';

void main() {
  test('booking details always has a role-correct bookings destination', () {
    expect(bookingListDestination(UserRole.customer), '/customer?tab=bookings');
    expect(bookingListDestination(UserRole.provider), '/provider?tab=bookings');
  });
}
