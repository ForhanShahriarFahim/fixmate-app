import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/routing/app_router.dart';
import 'package:fixmate/core/domain/models.dart';

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

  test('administrator resolution precedes an ordinary missing profile', () {
    expect(resolveSessionDestination(isAdmin: true, profile: null), '/admin');
    expect(resolveSessionDestination(isAdmin: false, profile: null), isNull);
    expect(
      resolveSessionDestination(
        isAdmin: false,
        profile: const AppUserProfile(
          id: 'customer',
          displayName: 'Customer',
          email: 'customer@example.com',
          phoneE164: '+8801700000000',
          role: UserRole.customer,
          status: AccountStatus.active,
          photoPath: null,
          termsVersion: '1.0',
          isAdultConfirmed: true,
        ),
      ),
      '/customer',
    );
  });

  test('role shells open requested tabs without invalid indexes', () {
    expect(shellTabIndex('bookings', provider: false), 1);
    expect(shellTabIndex('activity', provider: false), 2);
    expect(shellTabIndex('bookings', provider: true), 1);
    expect(shellTabIndex('services', provider: true), 2);
    expect(shellTabIndex('activity', provider: true), 3);
    expect(shellTabIndex('unknown', provider: true), 0);
  });
}
