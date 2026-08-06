import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fixmate/core/constants/app_constants.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/locations/bangladesh_locations.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/formatters.dart';
import 'package:fixmate/core/utils/validators.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';
import 'package:fixmate/features/catalog/catalog_screens.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({
    this.existing,
    this.onSubmitted,
    this.onSubmittingChanged,
    super.key,
  });
  final ProviderProfile? existing;
  final ValueChanged<ProviderProfile>? onSubmitted;
  final ValueChanged<bool>? onSubmittingChanged;

  @override
  ConsumerState<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState
    extends ConsumerState<ProviderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _experience;
  final _areaInput = TextEditingController();
  late List<String> _areas;
  String? _divisionCode;
  String? _districtCode;
  bool _loading = false;
  ProviderProfile? _submittedProfile;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.publicName);
    _bio = TextEditingController(text: widget.existing?.bio);
    _experience = TextEditingController(
      text: widget.existing?.experienceYears.toString() ?? '0',
    );
    _areas = [...?widget.existing?.serviceAreaLabels];
    _divisionCode = widget.existing?.divisionCode;
    _districtCode = widget.existing?.districtCode;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _experience.dispose();
    _areaInput.dispose();
    super.dispose();
  }

  void _addArea() {
    final value = _areaInput.text.trim();
    if (value.isEmpty || _areas.length >= AppConstants.maxServiceAreas) return;
    if (!_areas.any(
      (area) => Validators.normalizeKey(area) == Validators.normalizeKey(value),
    )) {
      setState(() => _areas.add(value));
    }
    _areaInput.clear();
  }

  Future<void> _save() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate() ||
        _divisionCode == null ||
        _districtCode == null ||
        _areas.isEmpty) {
      showMessage(
        context,
        'Complete your location and add at least one service area.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    widget.onSubmittingChanged?.call(true);
    var submitted = false;
    try {
      final profile = await ref.read(providerProfileSubmitterProvider)(
        ProviderProfileDraft(
          publicName: _name.text,
          bio: _bio.text,
          experienceYears: int.parse(_experience.text),
          divisionCode: _divisionCode!,
          districtCode: _districtCode!,
          serviceAreas: List<String>.unmodifiable(_areas),
        ),
      );
      if (!mounted) return;
      setState(() {
        _submittedProfile = profile;
        _loading = false;
      });
      submitted = true;
      widget.onSubmitted?.call(profile);
      if (widget.onSubmitted == null) {
        ref.invalidate(providerProfileProvider(profile.providerId));
      }
      widget.onSubmittingChanged?.call(false);
    } catch (error, stack) {
      if (kDebugMode) {
        final description = error is FirebaseException
            ? '${error.plugin}/${error.code}'
            : error.runtimeType.toString();
        debugPrint('Provider application failed ($description).');
        debugPrintStack(stackTrace: stack);
      }
      if (mounted) {
        showMessage(context, providerApplicationError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      if (!submitted) widget.onSubmittingChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedProfile = _submittedProfile;
    if (submittedProfile != null) {
      return ProviderApprovalScreen(
        profile: submittedProfile,
        submissionAcknowledged: true,
      );
    }
    final locations = ref.watch(bangladeshLocationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Provider application'
              : 'Edit provider profile',
        ),
      ),
      body: locations.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(message: friendlyError(error)),
        data: (divisions) {
          final division = _divisionCode == null
              ? null
              : divisions
                    .where((item) => item.code == _divisionCode)
                    .firstOrNull;
          if (_divisionCode != null && division == null) _divisionCode = null;
          final districtNames = division?.districts ?? const <String>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tell customers about your experience. An administrator will review your profile and phone number.',
                  ),
                  if (widget.existing?.isBookable == true) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Saving any public provider change temporarily removes your services from the FixMate interface until an administrator approves the updated profile.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    validator: (value) =>
                        Validators.requiredText(value, label: 'Public name'),
                    decoration: const InputDecoration(labelText: 'Public name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    validator: (value) =>
                        value == null || value.trim().length < 20
                        ? 'Write at least 20 characters.'
                        : null,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'About your work',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _experience,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final years = int.tryParse(value ?? '');
                      return years == null || years < 0 || years > 60
                          ? 'Enter experience from 0 to 60 years.'
                          : null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Years of experience',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _divisionCode,
                    decoration: const InputDecoration(labelText: 'Division'),
                    items: divisions
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.code,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _divisionCode = value;
                      _districtCode = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Choose a division.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _districtCode,
                    decoration: const InputDecoration(labelText: 'District'),
                    items: districtNames
                        .map(
                          (name) => DropdownMenuItem(
                            value: districtCode(name),
                            child: Text(name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _districtCode = value),
                    validator: (value) =>
                        value == null ? 'Choose a district.' : null,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Service areas (${_areas.length}/${AppConstants.maxServiceAreas})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _areaInput,
                          decoration: const InputDecoration(
                            hintText: 'Example: Dhanmondi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addArea,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add area',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _areas
                        .map(
                          (area) => InputChip(
                            label: Text(area),
                            onDeleted: () =>
                                setState(() => _areas.remove(area)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: Text(_loading ? 'Saving…' : 'Submit for approval'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProviderApprovalScreen extends ConsumerWidget {
  const ProviderApprovalScreen({
    required this.profile,
    this.submissionAcknowledged = false,
    super.key,
  });
  final ProviderProfile profile;
  final bool submissionAcknowledged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejected = profile.approvalStatus == ProviderApprovalStatus.rejected;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Provider account'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(signOutActionProvider)();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 68,
                    color: rejected
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    rejected
                        ? 'Application needs changes'
                        : 'Application under review',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (submissionAcknowledged) ...[
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Application submitted successfully. Your information is saved securely.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    rejected
                        ? 'Review the feedback below, edit the application, and resubmit it for another review.'
                        : 'A FixMate administrator will verify your submitted information and phone number. You can safely leave the app and check again later.',
                    textAlign: TextAlign.center,
                  ),
                  if (rejected && profile.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Administrator feedback',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(profile.rejectionReason),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!rejected) ...[
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Next steps\n\n1. Keep your email and phone details current.\n2. Check this screen later for the review result.\n3. Editing and resubmitting keeps the application pending until a new review is completed.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/provider/onboarding', extra: profile),
                    icon: const Icon(Icons.edit),
                    label: Text(
                      rejected
                          ? 'Edit and resubmit application'
                          : 'Edit application',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Account information'),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(signOutActionProvider)();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String providerApplicationError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'FixMate could not save your application. Confirm your email is verified, your account is active, and this debug device is registered with App Check if enforcement is enabled, then try again.';
  }
  return friendlyError(error);
}

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const LoadingView();
    final repository = ref.read(marketplaceRepositoryProvider);
    final reviews = ref.watch(providerReviewSummaryProvider(user.id));
    final stats = ref.watch(providerDashboardStatsProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${user.displayName.split(' ').first}'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: () {
              ref.invalidate(providerReviewSummaryProvider(user.id));
              ref.invalidate(providerDashboardStatsProvider(user.id));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<Booking>>(
        stream: repository.watchBookings(
          uid: user.id,
          role: UserRole.provider,
          limit: 20,
        ),
        builder: (context, bookingSnapshot) {
          if (bookingSnapshot.hasError) {
            return ErrorView(
              message: friendlyError(bookingSnapshot.error!),
              onRetry: () {
                ref.invalidate(providerReviewSummaryProvider(user.id));
                ref.invalidate(providerDashboardStatsProvider(user.id));
              },
            );
          }
          if (!bookingSnapshot.hasData) return const LoadingView();
          final bookings = bookingSnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _ProviderReputationCard(
                reviews: reviews,
                stats: stats,
                onRetry: () {
                  ref.invalidate(providerReviewSummaryProvider(user.id));
                  ref.invalidate(providerDashboardStatsProvider(user.id));
                },
              ),
              const SizedBox(height: 14),
              _ProviderAnalyticsGrid(
                stats: stats,
                onRetry: () =>
                    ref.invalidate(providerDashboardStatsProvider(user.id)),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Payment collection'),
                  subtitle: const Text(
                    'Completed earnings are confirmed cash payments. Online payments are planned but no gateway is connected in this release.',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Recent bookings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (bookings.isEmpty)
                const SizedBox(
                  height: 220,
                  child: EmptyView(
                    icon: Icons.calendar_month_outlined,
                    title: 'No bookings yet',
                    message: 'Your booking requests will appear here.',
                  ),
                )
              else
                ...bookings
                    .take(5)
                    .map(
                      (booking) => Card(
                        child: ListTile(
                          onTap: () => context.push('/booking/${booking.id}'),
                          title: Text(booking.serviceTitle),
                          subtitle: Text(
                            formatBookingSchedule(
                              booking.scheduleDateKey,
                              booking.timeWindow,
                            ),
                          ),
                          trailing: BookingStatusChip(status: booking.status),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderReputationCard extends StatelessWidget {
  const _ProviderReputationCard({
    required this.reviews,
    required this.stats,
    required this.onRetry,
  });

  final AsyncValue<ReviewSummary> reviews;
  final AsyncValue<ProviderDashboardStats> stats;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: reviews.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loading verified reputation…'),
            SizedBox(height: 10),
            LinearProgressIndicator(),
          ],
        ),
        error: (error, stack) => _DashboardMetricError(
          title: 'Reputation is temporarily unavailable',
          error: error,
          onRetry: onRetry,
        ),
        data: (review) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your verified reputation'),
            const SizedBox(height: 8),
            Text(
              review.hasReviews
                  ? '${review.average!.toStringAsFixed(1)} ★'
                  : 'No verified rating yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${review.count} verified reviews • '
              '${stats.value?.completed ?? 0} completed jobs',
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProviderAnalyticsGrid extends StatelessWidget {
  const _ProviderAnalyticsGrid({required this.stats, required this.onRetry});

  final AsyncValue<ProviderDashboardStats> stats;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => stats.when(
    loading: () => const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loading exact booking analytics…'),
            SizedBox(height: 10),
            LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    error: (error, stack) => _DashboardMetricError(
      title: 'Analytics are temporarily unavailable',
      error: error,
      onRetry: onRetry,
    ),
    data: (value) => Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'New requests',
                value: value.pending,
                icon: Icons.notifications_active_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Active jobs',
                value: value.active,
                icon: Icons.handyman_outlined,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Completed jobs',
                value: value.completed,
                icon: Icons.task_alt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Active services (${value.totalServices} total)',
                value: value.activeServices,
                icon: Icons.home_repair_service_outlined,
              ),
            ),
          ],
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(
              formatBdt(value.cashEarningsBdt),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: const Text('Confirmed cash earnings'),
          ),
        ),
      ],
    ),
  );
}

class _DashboardMetricError extends StatelessWidget {
  const _DashboardMetricError({
    required this.title,
    required this.error,
    this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(friendlyError(error)),
      if (onRetry != null)
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
}

class ProviderServicesScreen extends ConsumerStatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  ConsumerState<ProviderServicesScreen> createState() =>
      _ProviderServicesScreenState();
}

class _ProviderServicesScreenState
    extends ConsumerState<ProviderServicesScreen> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const LoadingView();
    return Scaffold(
      appBar: AppBar(title: const Text('My services')),
      body: StreamBuilder<List<ServiceListing>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchProviderServices(user.id, limit: _limit),
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
              icon: Icons.add_business_outlined,
              title: 'Publish your first service',
              message:
                  'Add a clear title, fixed price, and helpful description.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                snapshot.data!.length +
                (snapshot.data!.length >= _limit ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == snapshot.data!.length) {
                return OutlinedButton(
                  onPressed: () => setState(() => _limit += 50),
                  child: const Text('Load more services'),
                );
              }
              final service = snapshot.data![index];
              return ServiceCard(service: service).withEdit(
                context,
                onEdit: () =>
                    context.push('/provider/service-editor', extra: service),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/provider/service-editor'),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
    );
  }
}

extension on ServiceCard {
  Widget withEdit(BuildContext context, {required VoidCallback onEdit}) =>
      Stack(
        children: [
          this,
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
            ),
          ),
        ],
      );
}

class ServiceEditorScreen extends ConsumerStatefulWidget {
  const ServiceEditorScreen({this.service, super.key});
  final ServiceListing? service;
  @override
  ConsumerState<ServiceEditorScreen> createState() =>
      _ServiceEditorScreenState();
}

class _ServiceEditorScreenState extends ConsumerState<ServiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  String? _categoryId;
  ServiceStatus _status = ServiceStatus.active;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.service?.title);
    _description = TextEditingController(text: widget.service?.description);
    _price = TextEditingController(text: widget.service?.priceBdt.toString());
    _categoryId = widget.service?.categoryId;
    _status = widget.service?.status ?? ServiceStatus.active;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save(AppUserProfile user, ProviderProfile provider) async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      await repository.saveService(
        serviceId: widget.service?.id,
        providerId: user.id,
        categoryId: _categoryId!,
        title: _title.text,
        description: _description.text,
        priceBdt: int.parse(_price.text),
        districtCode: provider.districtCode,
        areaLabels: provider.serviceAreaLabels,
        status: _status,
      );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    final provider = ref.watch(providerProfileProvider(user.id));
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service == null ? 'Add service' : 'Edit service'),
      ),
      body: provider.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(message: friendlyError(error)),
        data: (profile) {
          if (profile == null || !profile.isBookable) {
            return const ErrorView(message: 'Provider approval is required.');
          }
          return categories.when(
            loading: () => const LoadingView(),
            error: (error, stack) => ErrorView(message: friendlyError(error)),
            data: (categoryItems) {
              final selectedCategory =
                  categoryItems.any((item) => item.id == _categoryId)
                  ? _categoryId
                  : null;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_repair_service, size: 42),
                            SizedBox(height: 8),
                            Text('Category artwork is used on the free plan.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (categoryItems.isEmpty) ...[
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text('No active categories available'),
                            subtitle: Text(
                              'Ask a FixMate administrator to add or activate a service category before publishing.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (_categoryId != null &&
                          selectedCategory == null) ...[
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.warning_amber_outlined),
                            title: Text('Previous category is inactive'),
                            subtitle: Text(
                              'Choose an active category before saving this service.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categoryItems
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Row(
                                  children: [
                                    Icon(categoryIcon(item.iconKey)),
                                    const SizedBox(width: 8),
                                    Text(item.name),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        validator: (value) =>
                            value == null ||
                                !categoryItems.any((item) => item.id == value)
                            ? 'Choose an active category.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        maxLength: 80,
                        validator: (value) =>
                            value == null || value.trim().length < 3
                            ? 'Use at least 3 characters.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Service title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        maxLength: 1000,
                        minLines: 4,
                        maxLines: 8,
                        validator: (value) =>
                            value == null || value.trim().length < 20
                            ? 'Use at least 20 characters.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final price = int.tryParse(value ?? '');
                          return price == null || price <= 0 || price > 1000000
                              ? 'Enter a price from ৳1 to ৳1,000,000.'
                              : null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Fixed price (BDT)',
                          prefixText: '৳ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _status == ServiceStatus.active,
                        onChanged: (value) => setState(
                          () => _status = value
                              ? ServiceStatus.active
                              : ServiceStatus.archived,
                        ),
                        title: const Text('Published'),
                        subtitle: const Text(
                          'Archived services remain visible only to you.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : () => _save(user, profile),
                        child: Text(_loading ? 'Saving…' : 'Save service'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
