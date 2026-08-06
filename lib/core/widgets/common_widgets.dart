import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fixmate/core/domain/models.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({required this.status, super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status) {
      BookingStatus.completed => Colors.green,
      BookingStatus.rejected || BookingStatus.cancelled => colors.error,
      BookingStatus.disputed => Colors.orange,
      BookingStatus.inProgress ||
      BookingStatus.completionRequested => colors.tertiary,
      _ => colors.primary,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      label: Text(_label(status)),
    );
  }

  String _label(BookingStatus value) => switch (value) {
    BookingStatus.inProgress => 'In progress',
    BookingStatus.completionRequested => 'Awaiting confirmation',
    _ => value.name[0].toUpperCase() + value.name.substring(1),
  };
}

class VerifiedReviewCard extends StatelessWidget {
  const VerifiedReviewCard({required this.review, super.key});

  final ServiceReview review;

  @override
  Widget build(BuildContext context) {
    final reviewedAt = review.createdAt == null
        ? 'Verified completed booking'
        : 'Verified booking • ${DateFormat.yMMMd().format(review.createdAt!.toLocal())}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.customerName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: '${review.rating} out of 5 stars',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < review.rating ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(reviewedAt, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              review.comment.trim().isEmpty
                  ? 'No written comment.'
                  : review.comment.trim(),
            ),
          ],
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
