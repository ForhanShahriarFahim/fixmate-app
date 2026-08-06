import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/locations/bangladesh_locations.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/formatters.dart';
import 'package:fixmate/core/utils/validators.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';

IconData categoryIcon(String key) => switch (key) {
  'electrical' => Icons.electrical_services,
  'plumbing' => Icons.plumbing,
  'cleaning' => Icons.cleaning_services,
  'ac' => Icons.ac_unit,
  'appliance' => Icons.home_repair_service,
  'painting' => Icons.format_paint,
  _ => Icons.handyman,
};

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  String? _categoryId;
  String? _divisionCode;
  String? _districtCode;
  String _areaKey = '';
  int? _maxPrice;
  String _search = '';
  int _serviceLimit = 20;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final locations = ref.watch(bangladeshLocationsProvider);
    final services = ref
        .read(marketplaceRepositoryProvider)
        .watchServices(
          categoryId: _categoryId,
          districtCode: _districtCode,
          limit: _serviceLimit,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FixMate'),
            Text(
              'Find trusted help nearby',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search electrical, cleaning, repair…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            locations.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (divisions) {
                final selectedDivision = _divisionCode == null
                    ? null
                    : divisions
                          .where((division) => division.code == _divisionCode)
                          .firstOrNull;
                final districts =
                    (selectedDivision?.districts ??
                          divisions
                              .expand((division) => division.districts)
                              .toList())
                      ..sort();
                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _divisionCode,
                      decoration: const InputDecoration(
                        labelText: 'Division',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All divisions'),
                        ),
                        ...divisions.map(
                          (division) => DropdownMenuItem<String?>(
                            value: division.code,
                            child: Text(division.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _divisionCode = value;
                        _districtCode = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: ValueKey(_divisionCode),
                      initialValue: _districtCode,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            selectedDivision == null
                                ? 'All Bangladesh'
                                : 'All ${selectedDivision.name} districts',
                          ),
                        ),
                        ...districts.map(
                          (district) => DropdownMenuItem<String?>(
                            value: districtCode(district),
                            child: Text(district),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _districtCode = value),
                    ),
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('More filters'),
                      leading: const Icon(Icons.tune),
                      children: [
                        TextField(
                          onChanged: (value) => setState(
                            () => _areaKey = Validators.normalizeKey(value),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Service area',
                            hintText: 'Example: Dhanmondi',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          initialValue: _maxPrice,
                          decoration: const InputDecoration(
                            labelText: 'Maximum price',
                          ),
                          items: const [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Any price'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 1000,
                              child: Text('৳1,000'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 2500,
                              child: Text('৳2,500'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 5000,
                              child: Text('৳5,000'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 10000,
                              child: Text('৳10,000'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _maxPrice = value),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text('Services', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: categories.when(
                loading: () => const LoadingView(),
                error: (error, stack) =>
                    ErrorView(message: friendlyError(error)),
                data: (items) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = index == 0 ? null : items[index - 1];
                    final selected =
                        category?.id == _categoryId ||
                        (category == null && _categoryId == null);
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _categoryId = category?.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 86,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              category == null
                                  ? Icons.apps
                                  : categoryIcon(category.iconKey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category?.name ?? 'All',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Available providers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<ServiceListing>>(
              stream: services,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: friendlyError(snapshot.error!),
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: LoadingView(),
                  );
                }
                final selectedDivision = _divisionCode == null
                    ? null
                    : locations.value
                          ?.where((division) => division.code == _divisionCode)
                          .firstOrNull;
                final divisionDistricts = selectedDivision?.districts
                    .map(districtCode)
                    .toSet();
                final items = snapshot.data!
                    .where(
                      (service) =>
                          (divisionDistricts == null ||
                              divisionDistricts.contains(
                                service.districtCode,
                              )) &&
                          (_areaKey.isEmpty ||
                              service.areaKeys.contains(_areaKey)) &&
                          (_maxPrice == null ||
                              service.priceBdt <= _maxPrice!) &&
                          (_search.isEmpty ||
                              service.title.toLowerCase().contains(_search) ||
                              service.providerName.toLowerCase().contains(
                                _search,
                              )),
                    )
                    .toList();
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 240,
                    child: EmptyView(
                      icon: Icons.home_repair_service_outlined,
                      title: 'No services found',
                      message:
                          'Try another category or district. New providers are added regularly.',
                    ),
                  );
                }
                return Column(
                  children: [
                    ...items.map((service) => ServiceCard(service: service)),
                    if (items.length >= _serviceLimit)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _serviceLimit += 20),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more services'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, super.key});
  final ServiceListing service;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/service/${service.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.handyman, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    service.providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 18),
                      const SizedBox(width: 4),
                      const Text('Approved provider'),
                      const Spacer(),
                      Text(
                        formatBdt(service.priceBdt),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({required this.serviceId, super.key});
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceProvider(serviceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: serviceAsync.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(serviceProvider(serviceId)),
        ),
        data: (service) {
          if (service == null) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Service unavailable',
              message: 'This service may have been archived.',
            );
          }
          final provider = ref.watch(
            providerProfileProvider(service.providerId),
          );
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: const Icon(Icons.home_repair_service, size: 72),
              ),
              const SizedBox(height: 20),
              Text(
                service.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(service.description),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  onTap: () => context.push('/provider/${service.providerId}'),
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(service.providerName),
                  subtitle: provider.when(
                    data: (value) => Text(
                      value?.isBookable == true
                          ? '${value!.experienceYears} years experience • approved provider'
                          : 'Provider is currently unavailable',
                    ),
                    loading: () => const Text('Loading provider…'),
                    error: (_, _) => const Text('Provider unavailable'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Service areas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: service.areaLabels
                    .map((area) => Chip(label: Text(area)))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fixed booking price',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    formatBdt(service.priceBdt),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: provider.value?.isBookable == true
                    ? () => context.push('/book/${service.id}')
                    : null,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  provider.value?.isBookable == true
                      ? 'Request booking'
                      : 'Provider unavailable',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recent reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              StreamBuilder<List<ServiceReview>>(
                stream: ref
                    .read(marketplaceRepositoryProvider)
                    .watchProviderReviews(service.providerId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Reviews temporarily unavailable'),
                        subtitle: Text(friendlyError(snapshot.error!)),
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No reviews yet.'),
                    );
                  }
                  final reviews = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<ReviewSummary>(
                        future: ref
                            .read(marketplaceRepositoryProvider)
                            .getProviderReviewSummary(service.providerId),
                        builder: (context, summary) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            summary.data?.hasReviews == true
                                ? '${summary.data!.average!.toStringAsFixed(1)} ★ from ${summary.data!.count} reviews'
                                : 'Customer reviews',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      ...reviews
                          .take(5)
                          .map((review) => VerifiedReviewCard(review: review)),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class PublicProviderProfileScreen extends ConsumerStatefulWidget {
  const PublicProviderProfileScreen({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<PublicProviderProfileScreen> createState() =>
      _PublicProviderProfileScreenState();
}

class _PublicProviderProfileScreenState
    extends ConsumerState<PublicProviderProfileScreen> {
  int _reviewLimit = 20;
  int _serviceLimit = 20;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerProfileProvider(widget.providerId));
    final repository = ref.read(marketplaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Provider profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: friendlyError(error),
          onRetry: () =>
              ref.invalidate(providerProfileProvider(widget.providerId)),
        ),
        data: (provider) {
          if (provider == null ||
              provider.approvalStatus != ProviderApprovalStatus.approved) {
            return const EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Provider unavailable',
              message: 'This public provider profile is not available.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Semantics(
                label: 'Provider ${provider.publicName}',
                child: CircleAvatar(
                  radius: 44,
                  child: Text(
                    provider.publicName.isEmpty
                        ? '?'
                        : provider.publicName[0].toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.publicName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                provider.isBookable
                    ? 'Approved FixMate provider'
                    : 'Currently unavailable for new bookings',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ref
                  .watch(providerReviewSummaryProvider(widget.providerId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: const Text('Verified rating unavailable'),
                        subtitle: Text(friendlyError(error)),
                        trailing: IconButton(
                          tooltip: 'Retry rating',
                          onPressed: () => ref.invalidate(
                            providerReviewSummaryProvider(widget.providerId),
                          ),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                    data: (summary) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.star_outline),
                        title: Text(
                          summary.hasReviews
                              ? '${summary.average!.toStringAsFixed(1)} out of 5'
                              : 'No verified rating yet',
                        ),
                        subtitle: Text(
                          summary.hasReviews
                              ? '${summary.count} verified customer reviews'
                              : 'A rating appears after a completed booking is reviewed.',
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text('About', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(provider.bio),
              const SizedBox(height: 8),
              Text('${provider.experienceYears} years of experience'),
              const SizedBox(height: 18),
              Text(
                'Approved service coverage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: provider.serviceAreaLabels
                    .map((area) => Chip(label: Text(area)))
                    .toList(growable: false),
              ),
              const SizedBox(height: 22),
              Text(
                'Active services',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              StreamBuilder<List<ServiceListing>>(
                stream: repository.watchProviderPublicServices(
                  widget.providerId,
                  limit: _serviceLimit,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(message: friendlyError(snapshot.error!));
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No active services are available.'),
                    );
                  }
                  return Column(
                    children: [
                      ...snapshot.data!.map(
                        (service) => ServiceCard(service: service),
                      ),
                      if (snapshot.data!.length >= _serviceLimit)
                        OutlinedButton(
                          onPressed: () => setState(() => _serviceLimit += 20),
                          child: const Text('Load more services'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(
                'Customer reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              StreamBuilder<List<ServiceReview>>(
                stream: repository.watchProviderReviews(
                  widget.providerId,
                  limit: _reviewLimit,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(message: friendlyError(snapshot.error!));
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No reviews yet.'),
                    );
                  }
                  return Column(
                    children: [
                      ...snapshot.data!.map(
                        (review) => VerifiedReviewCard(review: review),
                      ),
                      if (snapshot.data!.length >= _reviewLimit)
                        OutlinedButton(
                          onPressed: () => setState(() => _reviewLimit += 20),
                          child: const Text('Load more reviews'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'For privacy, phone numbers, email addresses, and booking addresses are never shown on public profiles.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({required this.serviceId, super.key});
  final String serviceId;
  @override
  ConsumerState<CreateBookingScreen> createState() =>
      _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  TimeWindow _window = TimeWindow.morning;
  String? _areaKey;
  bool _loading = false;

  @override
  void dispose() {
    _address.dispose();
    _landmark.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _submit(ServiceListing service) async {
    if (!_formKey.currentState!.validate() ||
        _date == null ||
        _areaKey == null) {
      showMessage(
        context,
        'Select a date, time window, and service area.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .runMutation('createBooking', <String, dynamic>{
            'serviceId': service.id,
            'dateKey': DateFormat('yyyy-MM-dd').format(_date!),
            'timeWindow': _window.name,
            'serviceAreaKey': _areaKey,
            'address': _address.text.trim(),
            'landmark': _landmark.text.trim(),
            'notes': _notes.text.trim(),
          });
      if (mounted) context.pushReplacement('/booking/${result['id']}');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceProvider(widget.serviceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Request booking')),
      body: service.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(message: friendlyError(error)),
        data: (value) {
          if (value == null) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Service unavailable',
              message: 'Choose another service.',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    value.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Locked price: ${formatBdt(value.priceBdt)}'),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _date == null
                          ? 'Choose service date'
                          : DateFormat.yMMMMd().format(_date!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<TimeWindow>(
                    initialValue: _window,
                    decoration: const InputDecoration(labelText: 'Time window'),
                    items: const [
                      DropdownMenuItem(
                        value: TimeWindow.morning,
                        child: Text('Morning • 08:00–12:00'),
                      ),
                      DropdownMenuItem(
                        value: TimeWindow.afternoon,
                        child: Text('Afternoon • 12:00–16:00'),
                      ),
                      DropdownMenuItem(
                        value: TimeWindow.evening,
                        child: Text('Evening • 16:00–20:00'),
                      ),
                    ],
                    onChanged: (selection) => setState(
                      () => _window = selection ?? TimeWindow.morning,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _areaKey,
                    decoration: const InputDecoration(
                      labelText: 'Service area',
                    ),
                    items: List.generate(
                      value.areaKeys.length,
                      (index) => DropdownMenuItem(
                        value: value.areaKeys[index],
                        child: Text(value.areaLabels[index]),
                      ),
                    ),
                    onChanged: (selection) =>
                        setState(() => _areaKey = selection),
                    validator: (selection) =>
                        selection == null ? 'Choose a service area.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    validator: (text) =>
                        Validators.requiredText(text, label: 'Address'),
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Street address',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _landmark,
                    decoration: const InputDecoration(
                      labelText: 'Nearby landmark (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    maxLength: 500,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Describe the work (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.check_circle),
                          title: Text('Cash after service'),
                          subtitle: Text(
                            'The customer confirms cash payment when accepting completion.',
                          ),
                        ),
                        Divider(height: 1),
                        ListTile(
                          enabled: false,
                          leading: Icon(Icons.credit_card_outlined),
                          title: Text('Online payment — coming later'),
                          subtitle: Text(
                            'No gateway is connected, so FixMate will not collect card or mobile-wallet details.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : () => _submit(value),
                    child: Text(
                      _loading ? 'Submitting…' : 'Submit booking request',
                    ),
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
