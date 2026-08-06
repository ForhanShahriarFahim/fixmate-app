import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';

void main() {
  testWidgets('verified review clearly shows rating, customer, and comment', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerifiedReviewCard(
            review: ServiceReview(
              bookingId: 'booking',
              providerId: 'provider',
              customerName: 'Customer One',
              rating: 4,
              comment: 'Careful and professional work.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Careful and professional work.'), findsOneWidget);
    expect(find.bySemanticsLabel('4 out of 5 stars'), findsOneWidget);
    expect(find.textContaining('Verified completed booking'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('empty review comment is labelled instead of disappearing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerifiedReviewCard(
            review: ServiceReview(
              bookingId: 'booking',
              providerId: 'provider',
              customerName: 'Customer Two',
              rating: 5,
              comment: '',
            ),
          ),
        ),
      ),
    );

    expect(find.text('No written comment.'), findsOneWidget);
  });
}
