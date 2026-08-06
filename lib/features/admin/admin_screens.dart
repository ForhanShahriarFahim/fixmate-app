import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';
import 'package:fixmate/features/catalog/catalog_screens.dart'
    show categoryIcon;

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentAdminMembershipProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider reviews'),
        actions: [
          IconButton(
            tooltip: 'Manage service categories',
            onPressed: () => context.push('/admin/categories'),
            icon: const Icon(Icons.category_outlined),
          ),
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
        child: StreamBuilder<List<ProviderProfile>>(
          stream: ref
              .read(marketplaceRepositoryProvider)
              .watchProviderApplications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                message: friendlyError(snapshot.error!),
                onRetry: () => ref.invalidate(currentAdminMembershipProvider),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final profiles = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(currentAdminMembershipProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.admin_panel_settings),
                          title: Text(
                            membership?.displayName ??
                                'Authorized FixMate administrator',
                          ),
                          subtitle: const Text(
                            'Only pending applications appear here. Approval changes are protected by Firestore Security Rules.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (profiles.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icons.fact_check_outlined,
                        title: 'No pending applications',
                        message:
                            'New provider applications will appear here for review.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          return Card(
                            child: ListTile(
                              minVerticalPadding: 14,
                              leading: CircleAvatar(
                                child: Text(
                                  profile.publicName.isEmpty
                                      ? '?'
                                      : profile.publicName[0].toUpperCase(),
                                ),
                              ),
                              title: Text(profile.publicName),
                              subtitle: Text(
                                '${profile.experienceYears} years experience\n'
                                '${profile.districtCode} • ${profile.serviceAreaLabels.join(', ')}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '/admin/provider/${profile.providerId}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  final _busy = <String>{};

  Future<void> _edit(ServiceCategory? category) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (context) => _CategoryEditorDialog(category: category),
    );
    if (draft == null || !mounted) return;
    if (category?.isActive == true && !draft.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate this category?'),
          content: const Text(
            'Providers will no longer be able to create or update services in this category. Existing active listings remain visible until reviewed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep active'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (_busy.contains(draft.id)) return;
    setState(() => _busy.add(draft.id));
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .saveCategory(
            categoryId: draft.id,
            createNew: category == null,
            name: draft.name,
            iconKey: draft.iconKey,
            order: draft.order,
            isActive: draft.isActive,
          );
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) {
        showMessage(
          context,
          category == null ? 'Service category added.' : 'Category updated.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(draft.id));
    }
  }

  Future<void> _delete(ServiceCategory category) async {
    if (category.isActive) {
      showMessage(
        context,
        'Deactivate ${category.name} before deleting it.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'This permanently removes the category and cannot be undone. Deletion is allowed only when no active or archived service still uses this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy.contains(category.id)) return;

    setState(() => _busy.add(category.id));
    try {
      await ref.read(marketplaceRepositoryProvider).deleteCategory(category.id);
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) showMessage(context, '${category.name} was deleted.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(category.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(adminCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service categories'),
        actions: [
          IconButton(
            tooltip: 'Refresh categories',
            onPressed: () => ref.invalidate(adminCategoriesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: categories.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: adminCategoryError(error),
          onRetry: () => ref.invalidate(adminCategoriesProvider),
        ),
        data: (items) {
          final active = items.where((item) => item.isActive).toList();
          final inactive = items.where((item) => !item.isActive).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text('${active.length} active service categories'),
                  subtitle: Text(
                    '${inactive.length} inactive • Deactivate before deleting an unused category.',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const EmptyView(
                  icon: Icons.category_outlined,
                  title: 'No service categories',
                  message: 'Add the first category providers can choose.',
                )
              else ...[
                _CategorySection(
                  title: 'Active',
                  description: 'Available for provider service listings',
                  items: active,
                  busy: _busy,
                  onEdit: _edit,
                  onDelete: _delete,
                ),
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _CategorySection(
                    title: 'Inactive',
                    description: 'Hidden from new and updated listings',
                    items: inactive,
                    busy: _busy,
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: categories.hasError ? null : () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
    );
  }
}

String adminCategoryError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase has not authorized category management for this administrator. The reviewed category Security Rules must be deployed before this screen can read or save categories.';
  }
  return friendlyError(error);
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.description,
    required this.items,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String description;
  final List<ServiceCategory> items;
  final Set<String> busy;
  final ValueChanged<ServiceCategory?> onEdit;
  final ValueChanged<ServiceCategory> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('No categories in this section'),
          ),
        )
      else
        ...items.map(
          (category) => AdminCategoryCard(
            category: category,
            busy: busy.contains(category.id),
            onEdit: () => onEdit(category),
            onDelete: () => onDelete(category),
          ),
        ),
    ],
  );
}

enum _CategoryAction { edit, delete }

class AdminCategoryCard extends StatelessWidget {
  const AdminCategoryCard({
    required this.category,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ServiceCategory category;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      minVerticalPadding: 12,
      leading: CircleAvatar(
        backgroundColor: category.isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(categoryIcon(category.iconKey)),
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${category.isActive ? 'Active' : 'Inactive'} • Display order ${category.order}\nID: ${category.id}',
      ),
      isThreeLine: true,
      trailing: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<_CategoryAction>(
              tooltip: 'Actions for ${category.name}',
              onSelected: (action) {
                switch (action) {
                  case _CategoryAction.edit:
                    onEdit();
                  case _CategoryAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Expanded(child: Text('Edit category')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CategoryAction.delete,
                  enabled: !category.isActive,
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.isActive
                              ? 'Delete unavailable'
                              : 'Delete category',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      onTap: busy ? null : onEdit,
    ),
  );
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.order,
    required this.isActive,
  });

  final String id;
  final String name;
  final String iconKey;
  final int order;
  final bool isActive;
}

String categoryIdFromName(String name) {
  var value = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (value.isNotEmpty && !RegExp(r'^[a-z]').hasMatch(value)) {
    value = 'service-$value';
  }
  if (value.length > 50) {
    value = value.substring(0, 50).replaceFirst(RegExp(r'-+$'), '');
  }
  return value;
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final ServiceCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _order;
  late String _iconKey;
  late bool _isActive;
  late bool _idManuallyEdited;

  static const _icons = <String, String>{
    'electrical': 'Electrical',
    'plumbing': 'Plumbing',
    'cleaning': 'Cleaning',
    'ac': 'Air conditioning',
    'appliance': 'Appliance',
    'painting': 'Painting',
    'handyman': 'General service',
  };

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _id = TextEditingController(text: category?.id);
    _name = TextEditingController(text: category?.name);
    _order = TextEditingController(text: category?.order.toString() ?? '10');
    _iconKey = category?.iconKey ?? 'handyman';
    _isActive = category?.isActive ?? true;
    _idManuallyEdited = category != null;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CategoryDraft(
        id: _id.text.trim(),
        name: _name.text.trim(),
        iconKey: _iconKey,
        order: int.parse(_order.text),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.category_outlined),
    title: Text(
      widget.category == null ? 'Add service category' : 'Edit category',
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.category == null
                    ? 'Create a provider-selectable type of work. The category ID becomes permanent after saving.'
                    : 'Update how this category appears and whether providers can select it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'The name customers and providers will see.',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onChanged: (value) {
                  if (widget.category == null && !_idManuallyEdited) {
                    _id.text = categoryIdFromName(value);
                  }
                },
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  return length < 2 ? 'Enter at least 2 characters.' : null;
                },
              ),
              TextFormField(
                controller: _id,
                readOnly: widget.category != null,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Permanent category ID',
                  helperText:
                      'Generated from the name. It cannot change after saving.',
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: widget.category == null
                      ? IconButton(
                          tooltip: 'Regenerate category ID',
                          onPressed: () {
                            _idManuallyEdited = false;
                            _id.text = categoryIdFromName(_name.text);
                          },
                          icon: const Icon(Icons.auto_fix_high),
                        )
                      : const Icon(Icons.lock_outline),
                ),
                onChanged: (_) => _idManuallyEdited = true,
                validator: (value) =>
                    RegExp(r'^[a-z][a-z0-9-]{1,49}$').hasMatch(value ?? '')
                    ? null
                    : 'Use a name such as Water Filter Repair.',
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _iconKey,
                decoration: const InputDecoration(
                  labelText: 'Category icon',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                items: _icons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(categoryIcon(entry.key)),
                            const SizedBox(width: 8),
                            Text(entry.value),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _iconKey = value ?? _iconKey),
              ),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display order',
                  helperText:
                      'Lower numbers appear first. Example: 10, 20, 30.',
                  prefixIcon: Icon(Icons.sort),
                ),
                validator: (value) {
                  final order = int.tryParse(value ?? '');
                  return order == null || order < 0 || order > 999
                      ? 'Use a number from 0 to 999.'
                      : null;
                },
              ),
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Available to providers'),
                  subtitle: const Text(
                    'Inactive categories cannot be selected for new or updated services.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.category == null ? 'Add category' : 'Save changes'),
      ),
    ],
  );
}

class AdminProviderReviewScreen extends ConsumerStatefulWidget {
  const AdminProviderReviewScreen({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<AdminProviderReviewScreen> createState() =>
      _AdminProviderReviewScreenState();
}

class _AdminProviderReviewScreenState
    extends ConsumerState<AdminProviderReviewScreen> {
  bool _submitting = false;

  Future<void> _approve(ProviderProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${profile.publicName}?'),
        content: const Text(
          'Approval makes this provider visible in the marketplace and allows service management. Confirm that the submitted identity, phone, experience, and coverage have been reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve provider'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _review(profile, decision: ProviderApprovalStatus.approved);
    }
  }

  Future<void> _reject(ProviderProfile profile) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RejectionReasonDialog(providerName: profile.publicName),
    );
    if (reason != null) {
      await _review(
        profile,
        decision: ProviderApprovalStatus.rejected,
        reason: reason,
      );
    }
  }

  Future<void> _review(
    ProviderProfile profile, {
    required ProviderApprovalStatus decision,
    String reason = '',
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .reviewProviderApplication(
            providerId: profile.providerId,
            decision: decision,
            rejectionReason: reason,
          );
      if (!mounted) return;
      showMessage(
        context,
        decision == ProviderApprovalStatus.approved
            ? 'Provider approved.'
            : 'Provider rejected with feedback.',
      );
      context.pop();
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerProfileProvider(widget.providerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review application')),
      body: SafeArea(
        child: profile.when(
          loading: () => const LoadingView(),
          error: (error, stack) => ErrorView(
            message: friendlyError(error),
            onRetry: () =>
                ref.invalidate(providerProfileProvider(widget.providerId)),
          ),
          data: (value) {
            if (value == null) {
              return const EmptyView(
                icon: Icons.person_off_outlined,
                title: 'Application unavailable',
                message:
                    'This provider application no longer exists or is no longer available to review.',
              );
            }
            final account = ref.watch(userProfileProvider(widget.providerId));
            final accountValue = account.value;
            final eligibleAccount =
                accountValue?.role == UserRole.provider &&
                accountValue?.status == AccountStatus.active;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  value.publicName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${value.experienceYears} years of experience'),
                const SizedBox(height: 18),
                account.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: const Text('Private account details unavailable'),
                      subtitle: Text(friendlyError(error)),
                    ),
                  ),
                  data: (user) => _ReviewSection(
                    title: 'Registered account',
                    body: user == null
                        ? 'The required FixMate user profile is missing. Do not approve this application.'
                        : '${user.displayName}\n${user.email}\n${user.phoneE164}\nAccount status: ${user.status.name}',
                  ),
                ),
                _ReviewSection(title: 'About', body: value.bio),
                _ReviewSection(
                  title: 'Coverage',
                  body:
                      '${value.divisionCode} division, ${value.districtCode} district',
                ),
                Text(
                  'Service areas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: value.serviceAreaLabels
                      .map((area) => Chip(label: Text(area)))
                      .toList(growable: false),
                ),
                const SizedBox(height: 24),
                if (value.approvalStatus == ProviderApprovalStatus.pending) ...[
                  FilledButton.icon(
                    onPressed: _submitting || !eligibleAccount
                        ? null
                        : () => _approve(value),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(
                      _submitting ? 'Saving review…' : 'Approve provider',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _reject(value),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject with reason'),
                  ),
                  if (!eligibleAccount) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Approval is disabled until an active provider account record can be verified. Rejection remains available.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ] else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Application already reviewed'),
                      subtitle: Text(value.approvalStatus.name),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body),
      ],
    ),
  );
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog({required this.providerName});

  final String providerName;

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Reject ${widget.providerName}'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: TextFormField(
          controller: _reason,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason for the provider',
            helperText: 'Explain what must be corrected before resubmitting.',
          ),
          validator: (value) => value == null || value.trim().length < 3
              ? 'Enter a reason of at least 3 characters.'
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
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Reject provider'),
      ),
    ],
  );
}
