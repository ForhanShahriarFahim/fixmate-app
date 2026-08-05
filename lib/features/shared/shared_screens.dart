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
    ActivityScreen(),
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
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Activity',
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
    ActivityScreen(),
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
        if (!profile.isBookable) {
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
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Activity',
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

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Recent activity')),
      body: StreamBuilder<List<FixMateNotification>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchActivity(uid: user.id, role: user.role),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: friendlyError(snapshot.error!));
          }
          if (!snapshot.hasData) return const LoadingView();
          if (snapshot.data!.isEmpty) {
            return const EmptyView(
              icon: Icons.history_outlined,
              title: 'No activity',
              message:
                  'Booking and message activity will appear here. Push notifications are not included in this release.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('In-app activity only'),
                    subtitle: Text(
                      'FixMate does not send push notifications in this release. Open the app to see booking and message updates.',
                    ),
                  ),
                );
              }
              final item = snapshot.data![index - 1];
              return Card(
                child: ListTile(
                  leading: Icon(_notificationIcon(item.type)),
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  onTap: () {
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

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final _busy = <String>{};
  int _limit = 50;

  Future<void> _unblock(BlockedUser blockedUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock ${blockedUser.displayName}?'),
        content: const Text(
          'Unblocking allows new messages and calls again when the related booking is still open. It does not change any booking status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep blocked'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy.contains(blockedUser.uid)) {
      return;
    }
    setState(() => _busy.add(blockedUser.uid));
    try {
      await ref.read(marketplaceRepositoryProvider).runMutation(
        'setUserBlocked',
        <String, dynamic>{'targetUid': blockedUser.uid, 'blocked': false},
      );
      if (mounted) showMessage(context, 'User unblocked.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(blockedUser.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: StreamBuilder<List<BlockedUser>>(
        stream: ref
            .read(marketplaceRepositoryProvider)
            .watchBlockedUsers(uid, limit: _limit),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: friendlyError(snapshot.error!));
          }
          if (!snapshot.hasData) return const LoadingView();
          if (snapshot.data!.isEmpty) {
            return const EmptyView(
              icon: Icons.block_outlined,
              title: 'No blocked users',
              message: 'People you block from a booking appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Blocking stops calls, new chat messages, and new bookings between both people. Existing profiles, bookings, chat history, and previously released booking addresses remain visible.',
                  ),
                ),
              ),
              ...snapshot.data!.map(
                (blockedUser) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.block)),
                    title: Text(blockedUser.displayName),
                    subtitle: const Text('Calls and messages blocked'),
                    trailing: TextButton(
                      onPressed: _busy.contains(blockedUser.uid)
                          ? null
                          : () => _unblock(blockedUser),
                      child: Text(
                        _busy.contains(blockedUser.uid)
                            ? 'Working…'
                            : 'Unblock',
                      ),
                    ),
                  ),
                ),
              ),
              if (snapshot.data!.length >= _limit)
                OutlinedButton(
                  onPressed: () => setState(() => _limit += 50),
                  child: const Text('Load more blocked users'),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
        content: SingleChildScrollView(
          child: Column(
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
      final nameError = name.text.trim().length < 2
          ? 'Enter a full name with at least 2 characters.'
          : null;
      if (phoneError != null || nameError != null) {
        if (context.mounted) {
          showMessage(context, nameError ?? phoneError!, error: true);
        }
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
        title: const Text('Request account deletion?'),
        content: const Text(
          'You must first cancel pending or accepted bookings. In-progress or disputed bookings must be resolved with support. '
          'This request immediately disables marketplace access. FixMate support must complete cleanup because the Spark plan has no trusted server cleanup. Some security and transaction records may be retained as described in the Privacy Policy.',
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
            child: const Text('Request deletion'),
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
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      await ref.read(authRepositoryProvider).reauthenticate(password);
      await ref
          .read(marketplaceRepositoryProvider)
          .runMutation('requestAccountDeletion', const <String, dynamic>{});
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) context.go('/');
    } catch (error) {
      if (navigator.canPop()) navigator.pop();
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
                      leading: const Icon(Icons.block_outlined),
                      title: const Text('Blocked users'),
                      subtitle: const Text('Manage call and chat blocks'),
                      onTap: () => context.push('/settings/blocked-users'),
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
                  'Request account deletion',
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
        'Use Profile → Request account deletion. Resolve or cancel active bookings first. The request immediately disables marketplace access, then FixMate support performs the documented administrative cleanup. If you cannot access the app, email ${AppConstants.supportEmail} from your registered email address.',
        AppConstants.deletionUrl,
      ),
      _ => (
        'Privacy Policy',
        'FixMate stores account details, provider profiles, booking addresses, messages, reviews, and moderation reports to operate and secure the marketplace. '
            'Addresses and phone numbers are limited to booking participants and released to providers only after acceptance. Crashlytics collects diagnostic data. '
            'Account deletion is completed administratively on the Spark plan. Limited historical and moderation records may be retained for security, disputes, and legal obligations as described in the full policy.',
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
