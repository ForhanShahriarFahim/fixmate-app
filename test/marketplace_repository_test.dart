import 'package:flutter_test/flutter_test.dart';
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
}
