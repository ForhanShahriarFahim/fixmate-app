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
import 'package:fixmate/core/widgets/common_widgets.dart';

class BookingListScreen extends ConsumerWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: StreamBuilder<List<Booking>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchBookings(uid: user.id, role: user.role),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: friendlyError(snapshot.error!));
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
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final booking = snapshot.data![index];
              final counterpart = user.role == UserRole.customer
                  ? booking.providerName
                  : booking.customerName;
              return Card(
                child: ListTile(
                  onTap: () => context.push('/booking/${booking.id}'),
                  title: Text(booking.serviceTitle),
                  subtitle: Text(
                    '$counterpart\n${booking.scheduleDateKey} • ${_windowLabel(booking.timeWindow)}',
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

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String function,
    Map<String, dynamic> data,
  ) async {
    try {
      await ref.read(marketplaceRepositoryProvider).runMutation(function, data);
      if (context.mounted) showMessage(context, 'Booking updated.');
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error), error: true);
      }
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
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

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Review service'),
          content: Column(
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
      await _act(context, ref, 'submitReview', <String, dynamic>{
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment.text.trim(),
      });
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
          content: Column(
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
                onChanged: (value) => setState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
          'Calls and new messages will be disabled. Booking history remains available.',
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
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking details'),
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
        error: (error, stack) => ErrorView(message: friendlyError(error)),
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
                        label: booking.scheduleDateKey,
                      ),
                      _DetailRow(
                        icon: Icons.schedule,
                        label: _windowLabel(booking.timeWindow),
                      ),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: booking.areaLabel,
                      ),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label:
                            '৳${NumberFormat.decimalPattern().format(booking.priceBdt)} • ${booking.paymentStatus.name}',
                      ),
                    ],
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
    if (isCustomer && booking.status == BookingStatus.completed) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _review(context, ref),
          icon: const Icon(Icons.star_outline),
          label: const Text('Leave a review'),
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
            'Calls are unavailable because one participant blocked the other.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report message?'),
        content: Text('“${message.text}”'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .runMutation('submitReport', <String, dynamic>{
            'bookingId': widget.bookingId,
            'targetType': ReportTarget.message.name,
            'targetId': message.id,
            'reason': 'objectionable_content',
            'details': '',
          });
      if (mounted) showMessage(context, 'Message reported for review.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
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
            MaterialBanner(
              content: const Text(
                'This booking is closed. Chat history is read-only.',
              ),
              actions: [
                TextButton(onPressed: () {}, child: const SizedBox.shrink()),
              ],
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref
                  .read(marketplaceRepositoryProvider)
                  .watchMessages(widget.bookingId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(message: friendlyError(snapshot.error!));
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
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    final own = item.senderId == uid;
                    return Align(
                      alignment: own
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
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
                                ? Theme.of(context).colorScheme.primaryContainer
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

String _windowLabel(TimeWindow window) => switch (window) {
  TimeWindow.morning => 'Morning • 08:00–12:00',
  TimeWindow.afternoon => 'Afternoon • 12:00–16:00',
  TimeWindow.evening => 'Evening • 16:00–20:00',
};

String _eventLabel(String type) => switch (type) {
  'inProgress' => 'Work started',
  'completionRequested' => 'Provider requested completion',
  'paidCash' => 'Cash payment confirmed',
  _ =>
    type.isEmpty
        ? 'Booking updated'
        : '${type[0].toUpperCase()}${type.substring(1)}',
};
