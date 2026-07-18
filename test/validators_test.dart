import 'package:flutter_test/flutter_test.dart';
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
}
