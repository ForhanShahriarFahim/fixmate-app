import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/formatters.dart';
import 'package:fixmate/core/utils/validators.dart';

void main() {
  group('Bangladesh phone validation', () {
    test('normalizes a local mobile number', () {
      expect(
        Validators.normalizeBangladeshPhone('01712-345678'),
        '+8801712345678',
      );
      expect(Validators.bangladeshPhone('01712-345678'), isNull);
    });

    test('rejects an invalid number', () {
      expect(Validators.bangladeshPhone('1234'), isNotNull);
    });
  });

  test('normalizes service area keys', () {
    expect(Validators.normalizeKey("Cox's Bazar"), 'cox-s-bazar');
  });

  test('formats BDT, dates, and booking windows consistently', () {
    expect(formatBdt(12500), '৳12,500');
    expect(formatDateKey('2030-01-02'), '2 Jan 2030');
    expect(formatTimeWindow(TimeWindow.morning), 'Morning • 08:00–12:00');
    expect(formatPaymentStatus(PaymentStatus.paidCash), 'Paid in cash');
  });
}
