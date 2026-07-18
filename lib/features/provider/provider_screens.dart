import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixmate/core/constants/app_constants.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/locations/bangladesh_locations.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/validators.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';
import 'package:fixmate/features/catalog/catalog_screens.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({this.existing, super.key});
  final ProviderProfile? existing;

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
    final user = ref.read(firebaseAuthProvider).currentUser!;
    setState(() => _loading = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .saveProviderProfile(
            providerId: user.uid,
            publicName: _name.text,
            bio: _bio.text,
            experienceYears: int.parse(_experience.text),
            divisionCode: _divisionCode!,
            districtCode: _districtCode!,
            serviceAreas: _areas,
            avatarUrl: widget.existing?.avatarUrl,
          );
      if (mounted) context.go('/provider');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

class ProviderApprovalScreen extends StatelessWidget {
  const ProviderApprovalScreen({required this.profile, super.key});
  final ProviderProfile profile;

  @override
  Widget build(BuildContext context) {
    final rejected = profile.approvalStatus == ProviderApprovalStatus.rejected;
    return Scaffold(
      appBar: AppBar(title: const Text('Provider account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
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
              Text(
                rejected
                    ? 'Update your provider details, then contact FixMate support for another review.'
                    : 'You can edit your profile while an administrator verifies your information and phone number.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/provider/onboarding', extra: profile),
                icon: const Icon(Icons.edit),
                label: const Text('Edit application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const LoadingView();
    final profile = ref.watch(providerProfileProvider(user.id)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${user.displayName.split(' ').first}'),
      ),
      body: StreamBuilder<List<Booking>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchBookings(uid: user.id, role: UserRole.provider),
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? const <Booking>[];
          final pending = bookings
              .where((item) => item.status == BookingStatus.pending)
              .length;
          final active = bookings
              .where(
                (item) => <BookingStatus>{
                  BookingStatus.accepted,
                  BookingStatus.inProgress,
                  BookingStatus.completionRequested,
                }.contains(item.status),
              )
              .length;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your reputation'),
                      const SizedBox(height: 8),
                      Text(
                        '${profile?.ratingAverage.toStringAsFixed(1) ?? '0.0'} ★',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${profile?.reviewCount ?? 0} reviews • ${profile?.completedBookings ?? 0} completed jobs',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'New requests',
                      value: pending,
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Active jobs',
                      value: active,
                      icon: Icons.handyman_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Recent bookings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (!snapshot.hasData)
                const LinearProgressIndicator()
              else if (bookings.isEmpty)
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
                            '${booking.scheduleDateKey} • ${booking.timeWindow.name}',
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

class ProviderServicesScreen extends ConsumerWidget {
  const ProviderServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const LoadingView();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My services'),
        actions: [
          IconButton(
            onPressed: () => context.push('/provider/service-editor'),
            icon: const Icon(Icons.add),
            tooltip: 'Add service',
          ),
        ],
      ),
      body: StreamBuilder<List<ServiceListing>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchProviderServices(user.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: friendlyError(snapshot.error!));
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
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
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
  XFile? _image;
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

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image != null) setState(() => _image = image);
  }

  Future<void> _save(AppUserProfile user, ProviderProfile provider) async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      var serviceId = await repository.saveService(
        serviceId: widget.service?.id,
        providerId: user.id,
        providerName: provider.publicName,
        categoryId: _categoryId!,
        title: _title.text,
        description: _description.text,
        priceBdt: int.parse(_price.text),
        districtCode: provider.districtCode,
        areaLabels: provider.serviceAreaLabels,
        status: _status,
        coverImageUrl: widget.service?.coverImageUrl,
      );
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final extension = _image!.name.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';
        final url = await repository.uploadImage(
          path: 'services/${user.id}/$serviceId/cover.$extension',
          bytes: bytes,
          contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        );
        serviceId = await repository.saveService(
          serviceId: serviceId,
          providerId: user.id,
          providerName: provider.publicName,
          categoryId: _categoryId!,
          title: _title.text,
          description: _description.text,
          priceBdt: int.parse(_price.text),
          districtCode: provider.districtCode,
          areaLabels: provider.serviceAreaLabels,
          status: _status,
          coverImageUrl: url,
        );
      }
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
          if (profile == null ||
              profile.approvalStatus != ProviderApprovalStatus.approved) {
            return const ErrorView(message: 'Provider approval is required.');
          }
          return categories.when(
            loading: () => const LoadingView(),
            error: (error, stack) => ErrorView(message: friendlyError(error)),
            data: (categoryItems) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          image: widget.service?.coverImageUrl == null
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(
                                    widget.service!.coverImageUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: Center(
                          child: Text(
                            _image == null
                                ? 'Tap to choose cover image'
                                : _image!.name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
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
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Choose a category.' : null,
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
            ),
          );
        },
      ),
    );
  }
}
