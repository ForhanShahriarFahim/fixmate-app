import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixmate/core/constants/app_constants.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/formatters.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';

String bookingListDestination(UserRole role) => role == UserRole.provider
    ? '/provider?tab=bookings'
    : '/customer?tab=bookings';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: StreamBuilder<List<Booking>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchBookings(uid: user.id, role: user.role, limit: _limit),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error!),
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) return const LoadingView();
          if (snapshot.data!.isEmpty) {
            return EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No bookings yet',
              message: user.role == UserRole.customer
                  ? 'Book a trusted home service and track it here.'
                  : 'New customer requests will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount:
                snapshot.data!.length +
                (snapshot.data!.length >= _limit ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == snapshot.data!.length) {
                return OutlinedButton.icon(
                  onPressed: () => setState(() => _limit += 50),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load older bookings'),
                );
              }
              final booking = snapshot.data![index];
              final counterpart = user.role == UserRole.customer
                  ? booking.providerName
                  : booking.customerName;
              return Card(
                child: ListTile(
                  onTap: () => context.push('/booking/${booking.id}'),
                  title: Text(booking.serviceTitle),
                  subtitle: Text(
                    '$counterpart\n${formatBookingSchedule(booking.scheduleDateKey, booking.timeWindow)}',
                  ),
                  isThreeLine: true,
                  trailing: BookingStatusChip(status: booking.status),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({required this.bookingId, super.key});
  final String bookingId;

  Future<bool> _act(
    BuildContext context,
    WidgetRef ref,
    String function,
    Map<String, dynamic> data,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      await ref.read(marketplaceRepositoryProvider).runMutation(function, data);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showMessage(context, 'Booking updated.');
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showMessage(context, friendlyError(error), error: true);
      }
      return false;
    }
  }

  Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required String label,
    int maxLength = 500,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: label,
                errorText:
                    controller.text.isNotEmpty &&
                        controller.text.trim().length < 3
                    ? 'Enter at least 3 characters.'
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: controller.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await _prompt(
      context,
      title: 'Cancel booking',
      label: 'Reason for cancellation',
    );
    if (reason == null || !context.mounted) return;
    await _act(context, ref, 'cancelBooking', <String, dynamic>{
      'bookingId': bookingId,
      'reason': 'other',
      'details': reason,
    });
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String providerId,
  ) async {
    var rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Review service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => setState(() => rating = index + 1),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: comment,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      final saved = await _act(context, ref, 'submitReview', <String, dynamic>{
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment.text.trim(),
      });
      if (saved) {
        ref.invalidate(providerReviewSummaryProvider(providerId));
      }
    }
    comment.dispose();
  }

  Future<void> _reportUser(
    BuildContext context,
    WidgetRef ref,
    String targetUid,
  ) async {
    var reason = 'unsafe_behavior';
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                      value: 'unsafe_behavior',
                      child: Text('Unsafe behavior'),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(value: 'fraud', child: Text('Fraud')),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLength: 1000,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: reason == 'other'
                        ? 'Details (required)'
                        : 'Details (optional)',
                    errorText:
                        reason == 'other' &&
                            detailsController.text.isNotEmpty &&
                            detailsController.text.trim().length < 3
                        ? 'Enter at least 3 characters.'
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed:
                  reason == 'other' && detailsController.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    final details = detailsController.text.trim();
    detailsController.dispose();
    if (submitted != true || !context.mounted) return;
    await _act(context, ref, 'submitReport', <String, dynamic>{
      'bookingId': bookingId,
      'targetType': ReportTarget.user.name,
      'targetId': targetUid,
      'reason': reason,
      'details': details,
    });
  }

  Future<void> _toggleBlock(
    BuildContext context,
    WidgetRef ref,
    String targetUid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'Calls, new messages, and new bookings between you will be disabled. Existing profiles, booking history, chat history, and already released booking addresses remain visible. You can unblock later from Profile → Blocked users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _act(context, ref, 'setUserBlocked', <String, dynamic>{
        'targetUid': targetUid,
        'blocked': true,
        'bookingId': bookingId,
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));
    final profile = ref.watch(currentUserProfileProvider).value;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final fallbackRoute = bookingListDestination(
      profile?.role ?? UserRole.customer,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking details'),
        leading: IconButton(
          tooltip: context.canPop() ? 'Back' : 'Return to bookings',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallbackRoute);
            }
          },
          icon: Icon(
            context.canPop() ? Icons.arrow_back : Icons.calendar_month_outlined,
          ),
        ),
        actions: [
          bookingAsync.value == null
              ? const SizedBox.shrink()
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    final booking = bookingAsync.value!;
                    final target = currentUid == booking.customerId
                        ? booking.providerId
                        : booking.customerId;
                    if (value == 'report') _reportUser(context, ref, target);
                    if (value == 'block') _toggleBlock(context, ref, target);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Report user')),
                    PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
                ),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const EmptyView(
              icon: Icons.event_busy,
              title: 'Booking unavailable',
              message: 'It may have been removed.',
            );
          }
          final isCustomer = booking.customerId == currentUid;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  BookingStatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isCustomer
                    ? 'Provider: ${booking.providerName}'
                    : 'Customer: ${booking.customerName}',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today,
                        label: formatDateKey(booking.scheduleDateKey),
                      ),
                      _DetailRow(
                        icon: Icons.schedule,
                        label: formatTimeWindow(booking.timeWindow),
                      ),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: booking.areaLabel,
                      ),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label:
                            '${formatBdt(booking.priceBdt)} • ${formatPaymentStatus(booking.paymentStatus)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Payment method: Cash'),
                  subtitle: Text(
                    booking.status == BookingStatus.completed
                        ? 'The customer confirmed ${formatBdt(booking.priceBdt)} was paid in cash.'
                        : 'Pay ${formatBdt(booking.priceBdt)} in cash after the work is completed. Online payment is planned but no payment gateway is connected yet.',
                  ),
                ),
              ),
              if (booking.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Work notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(booking.notes),
              ],
              if (booking.contactReleasedAt != null) ...[
                const SizedBox(height: 18),
                _ContactCard(bookingId: booking.id, isCustomer: isCustomer),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/booking/${booking.id}/chat'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    booking.canChat ? 'Open chat' : 'View chat history',
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (isCustomer && booking.status == BookingStatus.completed) ...[
                StreamBuilder<ServiceReview?>(
                  stream: ref
                      .read(marketplaceRepositoryProvider)
                      .watchBookingReview(booking.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: const Text('Review status unavailable'),
                          subtitle: Text(friendlyError(snapshot.error!)),
                          trailing: IconButton(
                            tooltip: 'Retry review status',
                            onPressed: () =>
                                ref.invalidate(bookingProvider(booking.id)),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData &&
                        snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final review = snapshot.data;
                    if (review != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your review',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          VerifiedReviewCard(review: review),
                          const Text(
                            'Each completed booking can be reviewed once. Published reviews cannot be edited in this release.',
                          ),
                        ],
                      );
                    }
                    return OutlinedButton.icon(
                      onPressed: () =>
                          _review(context, ref, booking.providerId),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Leave a review'),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              ..._actions(context, ref, booking, isCustomer),
              const SizedBox(height: 24),
              Text(
                'Booking timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<BookingEvent>>(
                stream: ref
                    .read(marketplaceRepositoryProvider)
                    .watchBookingEvents(booking.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return Column(
                    children: snapshot.data!
                        .map(
                          (event) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(_eventLabel(event.type)),
                            subtitle: Text(
                              event.createdAt == null
                                  ? 'Just now'
                                  : DateFormat.yMMMd().add_jm().format(
                                      event.createdAt!.toLocal(),
                                    ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.go(
                  bookingListDestination(
                    isCustomer ? UserRole.customer : UserRole.provider,
                  ),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to bookings'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
    bool isCustomer,
  ) {
    final actions = <Widget>[];
    if (!isCustomer && booking.status == BookingStatus.pending) {
      actions.add(
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final reason = await _prompt(
                    context,
                    title: 'Reject booking',
                    label: 'Reason',
                  );
                  if (reason != null && context.mounted) {
                    await _act(
                      context,
                      ref,
                      'respondToBooking',
                      <String, dynamic>{
                        'bookingId': booking.id,
                        'decision': 'reject',
                        'reason': reason,
                      },
                    );
                  }
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    _act(context, ref, 'respondToBooking', <String, dynamic>{
                      'bookingId': booking.id,
                      'decision': 'accept',
                    }),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      );
    }
    if (!isCustomer && booking.status == BookingStatus.accepted) {
      actions.add(
        FilledButton(
          onPressed: () => _act(context, ref, 'startBooking', <String, dynamic>{
            'bookingId': booking.id,
          }),
          child: const Text('Start work'),
        ),
      );
    }
    if (!isCustomer && booking.status == BookingStatus.inProgress) {
      actions.add(
        FilledButton(
          onPressed: () => _act(
            context,
            ref,
            'requestCompletion',
            <String, dynamic>{'bookingId': booking.id},
          ),
          child: const Text('Request completion'),
        ),
      );
    }
    if (isCustomer && booking.status == BookingStatus.completionRequested) {
      actions.add(
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final details = await _prompt(
                    context,
                    title: 'Dispute completion',
                    label: 'What needs attention?',
                  );
                  if (details != null && context.mounted) {
                    await _act(
                      context,
                      ref,
                      'disputeCompletion',
                      <String, dynamic>{
                        'bookingId': booking.id,
                        'reason': 'service_issue',
                        'details': details,
                      },
                    );
                  }
                },
                child: const Text('Dispute'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => _act(
                  context,
                  ref,
                  'confirmCompletion',
                  <String, dynamic>{'bookingId': booking.id},
                ),
                child: const Text('Confirm paid'),
              ),
            ),
          ],
        ),
      );
    }
    if (<BookingStatus>{
      BookingStatus.pending,
      BookingStatus.accepted,
    }.contains(booking.status)) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextButton(
            onPressed: () => _cancel(context, ref),
            child: const Text('Cancel booking'),
          ),
        ),
      );
    }
    return actions;
  }
}

class _ContactCard extends ConsumerWidget {
  const _ContactCard({required this.bookingId, required this.isCustomer});
  final String bookingId;
  final bool isCustomer;

  Future<void> _callParticipant(
    BuildContext context,
    WidgetRef ref,
    String phone,
  ) async {
    try {
      final response = await ref
          .read(marketplaceRepositoryProvider)
          .runMutation('checkCommunication', <String, dynamic>{
            'bookingId': bookingId,
          });
      if (response['status'] != 'allowed') {
        if (context.mounted) {
          showMessage(
            context,
            response['status'] == 'blocked'
                ? 'Calls are unavailable because one participant blocked the other.'
                : 'The other participant is not currently available for calls.',
            error: true,
          );
        }
        return;
      }
      if (context.mounted) {
        await launchUrl(Uri(scheme: 'tel', path: phone));
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<BookingContact?>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchBookingContact(bookingId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(friendlyError(snapshot.error!)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            );
          }
          final contact = snapshot.data!;
          final phone = isCustomer
              ? contact.providerPhone
              : contact.customerPhone;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Contact details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (!isCustomer) ...[
                    Text(contact.address),
                    if (contact.landmark.isNotEmpty)
                      Text('Landmark: ${contact.landmark}'),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: phone.isEmpty
                        ? null
                        : () => _callParticipant(context, ref, phone),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call participant'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.bookingId, super.key});
  final String bookingId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _message = TextEditingController();
  bool _sending = false;
  int _messageLimit = 50;
  final _reporting = <String>{};

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || text.length > AppConstants.maxMessageLength) return;
    setState(() => _sending = true);
    try {
      await ref.read(marketplaceRepositoryProvider).runMutation(
        'sendMessage',
        <String, dynamic>{'bookingId': widget.bookingId, 'text': text},
      );
      _message.clear();
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(ChatMessage message) async {
    if (_reporting.contains(message.id)) return;
    var reason = 'objectionable_content';
    final details = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '“${message.text}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                      value: 'objectionable_content',
                      child: Text('Objectionable content'),
                    ),
                    DropdownMenuItem(
                      value: 'abusive_content',
                      child: Text('Abusive content'),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'fraud', child: Text('Fraud')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  maxLength: 1000,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: reason == 'other'
                        ? 'Details (required)'
                        : 'Details (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: reason == 'other' && details.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    final reportDetails = details.text.trim();
    details.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _reporting.add(message.id));
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .runMutation('submitReport', <String, dynamic>{
            'bookingId': widget.bookingId,
            'targetType': ReportTarget.message.name,
            'targetId': message.id,
            'reason': reason,
            'details': reportDetails,
          });
      if (mounted) showMessage(context, 'Message reported for review.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _reporting.remove(message.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final canSend = booking.value?.canChat ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking chat')),
      body: Column(
        children: [
          if (!canSend)
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'This booking is closed. Chat history is read-only.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref
                  .read(marketplaceRepositoryProvider)
                  .watchMessages(widget.bookingId, limit: _messageLimit),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: friendlyError(snapshot.error!),
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) return const LoadingView();
                if (snapshot.data!.isEmpty) {
                  return const EmptyView(
                    icon: Icons.chat_bubble_outline,
                    title: 'Start the conversation',
                    message: 'Use chat to coordinate this booking safely.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount:
                      snapshot.data!.length +
                      (snapshot.data!.length >= _messageLimit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && snapshot.data!.length >= _messageLimit) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _messageLimit += 50),
                          icon: const Icon(Icons.expand_less),
                          label: const Text('Load older messages'),
                        ),
                      );
                    }
                    final messageIndex = snapshot.data!.length >= _messageLimit
                        ? index - 1
                        : index;
                    final item = snapshot.data![messageIndex];
                    final own = item.senderId == uid;
                    return Align(
                      alignment: own
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Semantics(
                        label:
                            '${own ? 'Your message' : 'Message from the other participant'}: ${item.text}',
                        hint: own ? null : 'Long press to report this message',
                        onLongPress: own ? null : () => _report(item),
                        child: GestureDetector(
                          onLongPress: own ? null : () => _report(item),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: own
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(item.text),
                                const SizedBox(height: 3),
                                Text(
                                  item.createdAt == null
                                      ? 'Sending…'
                                      : DateFormat.jm().format(
                                          item.createdAt!.toLocal(),
                                        ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: canSend,
                      maxLength: AppConstants.maxMessageLength,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'Write a message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: !canSend || _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _eventLabel(String type) => switch (type) {
  'inProgress' => 'Work started',
  'completionRequested' => 'Provider requested completion',
  'paidCash' => 'Cash payment confirmed',
  _ =>
    type.isEmpty
        ? 'Booking updated'
        : '${type[0].toUpperCase()}${type.substring(1)}',
};
