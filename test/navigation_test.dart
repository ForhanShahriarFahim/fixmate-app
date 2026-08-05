import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/routing/app_router.dart';

void main() {
  test('signed-out users are redirected from protected routes', () {
    expect(
      resolveAuthRedirect(
        signedIn: false,
        emailVerified: false,
        location: '/provider/provider-1',
      ),
      '/login',
    );
    expect(
      resolveAuthRedirect(
        signedIn: false,
        emailVerified: false,
        location: '/legal/privacy',
      ),
      isNull,
    );
  });

  test('verification and authenticated-entry redirects remain safe', () {
    expect(
      resolveAuthRedirect(
        signedIn: true,
        emailVerified: false,
        location: '/customer',
      ),
      '/verify-email',
    );
    expect(
      resolveAuthRedirect(
        signedIn: true,
        emailVerified: true,
        location: '/login',
      ),
      '/',
    );
    expect(
      resolveAuthRedirect(
        signedIn: true,
        emailVerified: true,
        location: '/booking/booking-1',
      ),
      isNull,
    );
  });
}
