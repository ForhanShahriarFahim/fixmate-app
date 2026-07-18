import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixmate/core/constants/app_constants.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/validators.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';
import 'package:fixmate/features/bookings/booking_screens.dart';
import 'package:fixmate/features/catalog/catalog_screens.dart';
import 'package:fixmate/features/provider/provider_screens.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  var _index = 0;
  static const _screens = <Widget>[
    CustomerHomeScreen(),
    BookingListScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _index, children: _screens),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});
  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  var _index = 0;
  static const _screens = <Widget>[
    ProviderDashboardScreen(),
    BookingListScreen(),
    ProviderServicesScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    final provider = ref.watch(providerProfileProvider(user.id));
    return provider.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) =>
          Scaffold(body: ErrorView(message: friendlyError(error))),
      data: (profile) {
        if (profile == null) return const ProviderOnboardingScreen();
        if (profile.approvalStatus != ProviderApprovalStatus.approved) {
          return ProviderApprovalScreen(profile: profile);
        }
        return Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_repair_service_outlined),
                selectedIcon: Icon(Icons.home_repair_service),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<FixMateNotification>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchNotifications(user.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: friendlyError(snapshot.error!));
          }
          if (!snapshot.hasData) return const LoadingView();
          if (snapshot.data!.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message: 'Booking and chat updates will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return Card(
                color: item.readAt == null
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: Icon(_notificationIcon(item.type)),
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  trailing: item.readAt == null
                      ? const Icon(Icons.circle, size: 10)
                      : null,
                  onTap: () async {
                    if (item.readAt == null) {
                      await ref
                          .read(marketplaceRepositoryProvider)
                          .markNotificationRead(user.id, item.id);
                    }
                    if (context.mounted && item.route.startsWith('/')) {
                      context.push(item.route);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

IconData _notificationIcon(NotificationType type) => switch (type) {
  NotificationType.booking => Icons.calendar_month_outlined,
  NotificationType.message => Icons.chat_bubble_outline,
  NotificationType.review => Icons.star_outline,
  NotificationType.moderation => Icons.shield_outlined,
  NotificationType.account => Icons.person_outline,
};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AppUserProfile profile,
  ) async {
    final name = TextEditingController(text: profile.displayName);
    final phone = TextEditingController(text: profile.phoneE164);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final phoneError = Validators.bangladeshPhone(phone.text);
      if (phoneError != null) {
        if (context.mounted) showMessage(context, phoneError, error: true);
      } else {
        try {
          await ref
              .read(authRepositoryProvider)
              .updateBasicProfile(displayName: name.text, phone: phone.text);
          if (context.mounted) showMessage(context, 'Profile updated.');
        } catch (error) {
          if (context.mounted) {
            showMessage(context, friendlyError(error), error: true);
          }
        }
      }
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'You must first cancel pending or accepted bookings. In-progress or disputed bookings must be resolved with support. '
          'Your profile, services, messages, media, and reviews will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Current password',
            helperText: 'Recent authentication is required for deletion.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).reauthenticate(password);
      await ref
          .read(marketplaceRepositoryProvider)
          .call('requestAccountDeletion', const <String, dynamic>{});
      if (context.mounted) context.go('/login');
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(message: friendlyError(error)),
        data: (user) {
          if (user == null) return const LoadingView();
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              CircleAvatar(
                radius: 42,
                child: Text(
                  user.displayName.isEmpty
                      ? '?'
                      : user.displayName[0].toUpperCase(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(user.email, textAlign: TextAlign.center),
              Text(
                user.role.name == 'customer'
                    ? 'Customer account'
                    : 'Provider account',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit account details'),
                      onTap: () => _edit(context, ref, user),
                    ),
                    if (user.role == UserRole.provider)
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Provider profile'),
                        onTap: () {
                          final provider = ref
                              .read(providerProfileProvider(user.id))
                              .value;
                          if (provider != null) {
                            context.push(
                              '/provider/onboarding',
                              extra: provider,
                            );
                          }
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms of Use'),
                      onTap: () => context.push('/legal/terms'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      onTap: () => context.push('/legal/privacy'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Account deletion information'),
                      onTap: () => context.push('/legal/delete'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: const Text('Contact support'),
                      subtitle: const Text(AppConstants.supportEmail),
                      onTap: () => launchUrl(
                        Uri(
                          scheme: 'mailto',
                          path: AppConstants.supportEmail,
                          queryParameters: {'subject': 'FixMate support'},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(notificationServiceProvider).clearForUser();
                  } catch (_) {
                    // Authentication sign-out must still proceed offline.
                  }
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _delete(context, ref),
                child: Text(
                  'Delete account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});
  final String document;

  @override
  Widget build(BuildContext context) {
    final (title, body, url) = switch (document) {
      'terms' => (
        'Terms of Use',
        'FixMate is for adults aged 18 or older. Be respectful, provide accurate booking information, and do not send abusive, illegal, deceptive, sexual, or threatening content. '
            'Providers are independent service providers. Prices shown at booking are fixed for that booking and payment is made in cash after service. Users may report or block others. Accounts that misuse the service may be suspended.',
        AppConstants.termsUrl,
      ),
      'delete' => (
        'Delete your account',
        'Use Profile → Delete account for in-app deletion. Resolve in-progress or disputed bookings first. If you cannot access the app, email ${AppConstants.supportEmail} from your registered email address and request FixMate account deletion.',
        AppConstants.deletionUrl,
      ),
      _ => (
        'Privacy Policy',
        'FixMate stores account details, provider profiles, booking addresses, messages, reviews, device tokens, and moderation reports to operate and secure the marketplace. '
            'Addresses and phone numbers are limited to booking participants and released to providers only after acceptance. Crashlytics collects diagnostic data. '
            'Account deletion removes personal content and anonymizes limited historical and moderation records as described in the full policy.',
        AppConstants.privacyUrl,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Text(body),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open full document'),
          ),
        ],
      ),
    );
  }
}
