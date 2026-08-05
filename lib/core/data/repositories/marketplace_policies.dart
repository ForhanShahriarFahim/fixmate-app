import 'package:fixmate/core/domain/models.dart';

/// Pure marketplace policies shared by repository validation and tests.
abstract final class MarketplacePolicies {
  static const userReportReasons = <String>{
    'harassment',
    'fraud',
    'spam',
    'unsafe_behavior',
    'other',
  };

  static const messageReportReasons = <String>{
    'abusive_content',
    'harassment',
    'spam',
    'fraud',
    'objectionable_content',
    'other',
  };

  static bool isValidReport({
    required ReportTarget target,
    required String reason,
    required String details,
  }) {
    final reasons = switch (target) {
      ReportTarget.user => userReportReasons,
      ReportTarget.message => messageReportReasons,
    };
    return reasons.contains(reason) &&
        details.length <= 1000 &&
        (reason != 'other' || details.length >= 3);
  }

  static String reportDocumentId({
    required String reporterId,
    required String bookingId,
    required ReportTarget target,
    required String targetId,
  }) => '${reporterId}_${bookingId}_${target.name}_$targetId';
}
