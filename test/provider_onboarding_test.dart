import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/locations/bangladesh_locations.dart';
import 'package:fixmate/features/provider/provider_screens.dart';
import 'package:fixmate/features/shared/shared_screens.dart';

ProviderProfile _profile({
  ProviderApprovalStatus approval = ProviderApprovalStatus.rejected,
  bool visible = false,
  String rejectionReason = '',
}) => ProviderProfile(
  providerId: 'provider-1',
  publicName: 'Provider User',
  avatarUrl: null,
  bio: 'A sufficiently detailed public provider biography.',
  experienceYears: 5,
  divisionCode: 'dhaka',
  districtCode: 'dhaka',
  serviceAreaLabels: const ['Dhanmondi'],
  serviceAreaKeys: const ['dhanmondi'],
  approvalStatus: approval,
  marketplaceVisible: visible,
  rejectionReason: rejectionReason,
);

const _userProfile = AppUserProfile(
  id: 'provider-1',
  displayName: 'Provider User',
  email: 'provider@example.com',
  phoneE164: '+8801700000000',
  role: UserRole.provider,
  status: AccountStatus.active,
  photoPath: null,
  termsVersion: '1.0',
  isAdultConfirmed: true,
);

Widget _providerShell(ProviderProfile profile) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    currentUserProfileProvider.overrideWith(
      (ref) => Stream.value(_userProfile),
    ),
    providerProfileProvider(
      _userProfile.id,
    ).overrideWith((ref) => Stream.value(profile)),
  ],
  child: const MaterialApp(home: ProviderShell()),
);

Future<void> _pumpForm(
  WidgetTester tester,
  ProviderProfileSubmitter submitter,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bangladeshLocationsProvider.overrideWith(
          (ref) async => const [
            BangladeshDivision(
              code: 'dhaka',
              name: 'Dhaka',
              districts: ['Dhaka'],
            ),
          ],
        ),
        providerProfileSubmitterProvider.overrideWith((ref) => submitter),
      ],
      child: MaterialApp(home: ProviderOnboardingScreen(existing: _profile())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful submission immediately shows pending review', (
    tester,
  ) async {
    var submissions = 0;
    await _pumpForm(tester, (draft) async {
      submissions++;
      expect(draft.publicName, 'Provider User');
      return _profile(approval: ProviderApprovalStatus.pending);
    });

    await tester.ensureVisible(find.text('Submit for approval'));
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    expect(find.text('Application under review'), findsOneWidget);
    expect(find.textContaining('submitted successfully'), findsOneWidget);
    expect(find.text('Provider application'), findsNothing);
  });

  testWidgets('failed submission keeps form data and shows useful failure', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );

    await tester.ensureVisible(find.text('Submit for approval'));
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();

    expect(find.text('Edit provider profile'), findsOneWidget);
    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller?.text, 'Provider User');
    expect(
      find.textContaining('Confirm your email is verified'),
      findsOneWidget,
    );
  });

  testWidgets('submission button prevents duplicate in-flight writes', (
    tester,
  ) async {
    final completion = Completer<ProviderProfile>();
    var submissions = 0;
    await _pumpForm(tester, (_) {
      submissions++;
      return completion.future;
    });

    await tester.ensureVisible(find.text('Submit for approval'));
    await tester.tap(find.text('Submit for approval'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(submissions, 1);

    completion.complete(_profile(approval: ProviderApprovalStatus.pending));
    await tester.pumpAndSettle();
    expect(find.text('Application under review'), findsOneWidget);
  });

  testWidgets('persisted pending profile reconstructs review after restart', (
    tester,
  ) async {
    final pending = _profile(approval: ProviderApprovalStatus.pending);

    await tester.pumpWidget(_providerShell(pending));
    await tester.pumpAndSettle();
    expect(find.text('Application under review'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_providerShell(pending));
    await tester.pumpAndSettle();
    expect(find.text('Application under review'), findsOneWidget);
    expect(find.text('Provider application'), findsNothing);
  });

  testWidgets('rejected provider sees feedback and explicit recovery actions', (
    tester,
  ) async {
    final rejected = _profile(
      rejectionReason: 'Add clearer service areas before resubmitting.',
    );
    await tester.pumpWidget(_providerShell(rejected));
    await tester.pumpAndSettle();

    expect(find.text('Application needs changes'), findsOneWidget);
    expect(
      find.text('Add clearer service areas before resubmitting.'),
      findsOneWidget,
    );
    expect(find.text('Edit and resubmit application'), findsOneWidget);
    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('Sign out'), findsWidgets);
  });
}
