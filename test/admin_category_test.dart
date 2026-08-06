import 'package:fixmate/core/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate/features/admin/admin_screens.dart';
import 'package:flutter/material.dart';

void main() {
  test('category IDs are generated as stable lowercase slugs', () {
    expect(categoryIdFromName('Water Filter Repair'), 'water-filter-repair');
    expect(categoryIdFromName('  AC & Cooling  '), 'ac-cooling');
    expect(categoryIdFromName('24 Hour Plumbing'), 'service-24-hour-plumbing');
    expect(categoryIdFromName('***'), isEmpty);
  });

  test('generated category IDs remain within the Firestore rule limit', () {
    final value = categoryIdFromName(
      'A very long category name that should be safely shortened for storage',
    );
    expect(value.length, lessThanOrEqualTo(50));
    expect(RegExp(r'^[a-z][a-z0-9-]{1,49}$').hasMatch(value), isTrue);
  });

  testWidgets('active category clearly requires deactivation before deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCategoryCard(
            category: const ServiceCategory(
              id: 'electrical',
              name: 'Electrical',
              iconKey: 'electrical',
              order: 10,
              isActive: true,
            ),
            busy: false,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Actions for Electrical'));
    await tester.pumpAndSettle();

    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Delete unavailable'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem && !widget.enabled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('inactive category exposes edit and permanent delete actions', (
    tester,
  ) async {
    var edited = false;
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCategoryCard(
            category: const ServiceCategory(
              id: 'unused-category',
              name: 'Unused category',
              iconKey: 'handyman',
              order: 90,
              isActive: false,
            ),
            busy: false,
            onEdit: () => edited = true,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Unused category'));
    expect(edited, isTrue);

    await tester.tap(find.byTooltip('Actions for Unused category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
