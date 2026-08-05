import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/domain/models.dart';

void main() {
  ProviderProfile profile({
    required ProviderApprovalStatus approval,
    required bool visible,
  }) => ProviderProfile(
    providerId: 'provider',
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
  );

  test('provider is bookable only when approved and marketplace visible', () {
    expect(
      profile(
        approval: ProviderApprovalStatus.approved,
        visible: true,
      ).isBookable,
      isTrue,
    );
    expect(
      profile(
        approval: ProviderApprovalStatus.pending,
        visible: true,
      ).isBookable,
      isFalse,
    );
    expect(
      profile(
        approval: ProviderApprovalStatus.approved,
        visible: false,
      ).isBookable,
      isFalse,
    );
  });

  test('zero-review summary never presents a rating', () {
    const empty = ReviewSummary(count: 0, average: null);
    const reviewed = ReviewSummary(count: 2, average: 4.5);
    expect(empty.hasReviews, isFalse);
    expect(reviewed.hasReviews, isTrue);
  });
}
