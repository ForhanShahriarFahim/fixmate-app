import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/data/repositories/auth_repository.dart';

void main() {
  test(
    'verification refresh reloads before forcing a fresh ID token',
    () async {
      final operations = <String>[];
      const refreshedUser = 'refreshed-user';

      final result = await reloadAndRefreshIdToken<String>(
        reload: () async => operations.add('reload'),
        refreshedUser: () {
          operations.add('current-user');
          return refreshedUser;
        },
        forceRefreshIdToken: (user) async {
          operations.add('force-token:$user');
        },
      );

      expect(result, refreshedUser);
      expect(operations, const [
        'reload',
        'current-user',
        'force-token:refreshed-user',
      ]);
    },
  );

  test('verification refresh stops when the reloaded session disappeared', () {
    expect(
      () => reloadAndRefreshIdToken<String>(
        reload: () async {},
        refreshedUser: () => null,
        forceRefreshIdToken: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
  });
}
