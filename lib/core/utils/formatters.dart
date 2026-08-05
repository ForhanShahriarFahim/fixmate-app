import 'package:intl/intl.dart';
import 'package:fixmate/core/domain/models.dart';

String formatBdt(int amount) =>
    '৳${NumberFormat.decimalPattern().format(amount)}';

String formatDateKey(String dateKey) {
  final date = DateTime.tryParse(dateKey);
  return date == null ? dateKey : DateFormat('d MMM yyyy').format(date);
}

String formatTimeWindow(TimeWindow window) => switch (window) {
  TimeWindow.morning => 'Morning • 08:00–12:00',
  TimeWindow.afternoon => 'Afternoon • 12:00–16:00',
  TimeWindow.evening => 'Evening • 16:00–20:00',
};

String formatBookingSchedule(String dateKey, TimeWindow window) =>
    '${formatDateKey(dateKey)} • ${formatTimeWindow(window)}';

String formatPaymentStatus(PaymentStatus status) => switch (status) {
  PaymentStatus.unpaid => 'Cash not confirmed',
  PaymentStatus.paidCash => 'Paid in cash',
  PaymentStatus.disputed => 'Payment disputed',
};
