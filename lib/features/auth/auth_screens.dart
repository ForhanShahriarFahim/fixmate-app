import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fixmate/core/data/firebase_providers.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/error_messages.dart';
import 'package:fixmate/core/utils/validators.dart';
import 'package:fixmate/core/widgets/common_widgets.dart';

class SessionGateScreen extends ConsumerStatefulWidget {
  const SessionGateScreen({super.key});

  @override
  ConsumerState<SessionGateScreen> createState() => _SessionGateScreenState();
}

class _SessionGateScreenState extends ConsumerState<SessionGateScreen> {
  Timer? _slowTimer;
  bool _takingLonger = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _startSlowTimer();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _takingLonger = true);
    });
  }

  void _retry() {
    setState(() => _takingLonger = false);
    _startSlowTimer();
    ref.invalidate(authStateProvider);
    ref.invalidate(authenticatedSessionReadyProvider);
    ref.invalidate(currentAdminMembershipProvider);
    ref.invalidate(currentUserProfileProvider);
  }

  Future<void> _returnToSignIn() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(signOutActionProvider)();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        setState(() => _signingOut = false);
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  Widget _loading(String stageLabel) => Scaffold(
    body: StartupLoadingView(
      stageLabel: stageLabel,
      takingLonger: _takingLonger,
      signingOut: _signingOut,
      onRetry: _retry,
      onReturnToSignIn: _returnToSignIn,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => _loading('sign-in session'),
      error: (error, stack) =>
          Scaffold(body: ErrorView(message: friendlyError(error))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go('/login'),
          );
          return _loading('sign-in screen');
        }
        if (!user.emailVerified) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go('/verify-email'),
          );
          return _loading('email verification');
        }
        final session = ref.watch(authenticatedSessionReadyProvider);
        return session.when(
          loading: () => _loading('secure sign-in session'),
          error: (error, stack) => ProfileLoadErrorScreen(
            error: error,
            onRetry: () => ref.invalidate(authenticatedSessionReadyProvider),
          ),
          data: (_) {
            final admin = ref.watch(currentAdminMembershipProvider);
            return admin.when(
              loading: () => _loading('administrator access'),
              error: (error, stack) => ProfileLoadErrorScreen(
                error: error,
                onRetry: () => ref.invalidate(currentAdminMembershipProvider),
              ),
              data: (membership) {
                if (membership?.active == true) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => context.go('/admin'),
                  );
                  return _loading('administrator dashboard');
                }
                final profile = ref.watch(currentUserProfileProvider);
                return profile.when(
                  loading: () => _loading('account profile'),
                  error: (error, stack) => ProfileLoadErrorScreen(
                    error: error,
                    onRetry: () => ref.invalidate(currentUserProfileProvider),
                  ),
                  data: (value) {
                    if (value == null) {
                      return MissingProfileRecoveryScreen(
                        onRetry: () {
                          ref.invalidate(currentAdminMembershipProvider);
                          ref.invalidate(currentUserProfileProvider);
                        },
                      );
                    }
                    if (value.status != AccountStatus.active) {
                      return AccountRestrictedScreen(profile: value);
                    }
                    final path = value.role == UserRole.customer
                        ? '/customer'
                        : '/provider';
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => context.go(path),
                    );
                    return _loading('account dashboard');
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class StartupLoadingView extends StatelessWidget {
  const StartupLoadingView({
    required this.stageLabel,
    required this.takingLonger,
    required this.signingOut,
    required this.onRetry,
    required this.onReturnToSignIn,
    super.key,
  });

  final String stageLabel;
  final bool takingLonger;
  final bool signingOut;
  final VoidCallback onRetry;
  final VoidCallback onReturnToSignIn;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_repair_service,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'FixMate',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(
                takingLonger
                    ? 'FixMate is still waiting for Firebase to confirm your $stageLabel.'
                    : 'Checking your $stageLabel…',
                textAlign: TextAlign.center,
              ),
              if (takingLonger) ...[
                const SizedBox(height: 8),
                const Text(
                  'Check your internet connection, then retry. If this session is stale, return to sign in safely.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: signingOut ? null : onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                TextButton.icon(
                  onPressed: signingOut ? null : onReturnToSignIn,
                  icon: signingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(signingOut ? 'Returning…' : 'Return to sign in'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class MissingProfileRecoveryScreen extends ConsumerStatefulWidget {
  const MissingProfileRecoveryScreen({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  ConsumerState<MissingProfileRecoveryScreen> createState() =>
      _MissingProfileRecoveryScreenState();
}

class _MissingProfileRecoveryScreenState
    extends ConsumerState<MissingProfileRecoveryScreen> {
  bool _returningToSignIn = false;

  Future<void> _returnToSignIn() async {
    if (_returningToSignIn) return;
    setState(() => _returningToSignIn = true);
    try {
      await ref.read(signOutActionProvider)();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        setState(() => _returningToSignIn = false);
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_returnToSignIn());
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Complete account setup'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(
                    Icons.manage_accounts_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your FixMate account setup is incomplete',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You signed in successfully, but the FixMate profile for this account could not be found. Return to sign in and use another account, or contact FixMate support if this account should have a profile.',
                    textAlign: TextAlign.center,
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _returningToSignIn ? null : widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check again'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _returningToSignIn ? null : _returnToSignIn,
                    icon: const Icon(Icons.login),
                    label: Text(
                      _returningToSignIn ? 'Signing out…' : 'Return to sign in',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Support: fixmatebd.support@gmail.com',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ProfileLoadErrorScreen extends ConsumerWidget {
  const ProfileLoadErrorScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Account temporarily unavailable'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 60,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'FixMate could not load your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(friendlyError(error), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    await ref.read(signOutActionProvider)();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Return to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccountRestrictedScreen extends ConsumerWidget {
  const AccountRestrictedScreen({required this.profile, super.key});

  final AppUserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletionPending =
        profile.status == AccountStatus.deletionPending ||
        profile.status == AccountStatus.deleted;
    return Scaffold(
      appBar: AppBar(title: const Text('FixMate account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    deletionPending ? Icons.delete_outline : Icons.lock_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    deletionPending
                        ? 'Account deletion requested'
                        : 'Account suspended',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (deletionPending)
                    StreamBuilder<DeletionRequest?>(
                      stream: ref
                          .read(marketplaceRepositoryProvider)
                          .watchDeletionRequest(profile.id),
                      builder: (context, snapshot) => Text(
                        _deletionStatusMessage(snapshot.data?.status),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const Text(
                      'Marketplace actions are disabled. Contact fixmatebd.support@gmail.com if you believe this is a mistake.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref.read(signOutActionProvider)();
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

String _deletionStatusMessage(
  DeletionRequestStatus? status,
) => switch (status) {
  DeletionRequestStatus.cleanupInProgress =>
    'Administrative cleanup is in progress. Marketplace access remains disabled.',
  DeletionRequestStatus.cleanupFailed =>
    'Cleanup needs administrator attention. Contact FixMate support from your registered email.',
  DeletionRequestStatus.completed =>
    'Administrative cleanup is complete. Sign out to leave this account.',
  _ =>
    'Your request is queued for administrator review. This does not mean cleanup is complete. Contact support if you need an update.',
};

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(signInActionProvider)(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.handyman_rounded,
                    size: 68,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to FixMate',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trusted home services across Bangladesh',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    validator: Validators.password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Signing in…' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _adult = false;
  bool _terms = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_adult || !_terms) {
      showMessage(
        context,
        'Confirm that you are 18+ and accept the Terms.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            displayName: _name.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text,
            role: _role,
            isAdultConfirmed: _adult,
            acceptedTerms: _terms,
          );
      if (mounted) context.go('/verify-email');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'I want to…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                        value: UserRole.customer,
                        icon: Icon(Icons.search),
                        label: Text('Book services'),
                      ),
                      ButtonSegment(
                        value: UserRole.provider,
                        icon: Icon(Icons.handyman),
                        label: Text('Provide services'),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: (value) =>
                        setState(() => _role = value.first),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    validator: (value) =>
                        Validators.requiredText(value, label: 'Name'),
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    validator: Validators.bangladeshPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '01XXXXXXXXX',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    validator: Validators.password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _adult,
                    onChanged: (value) =>
                        setState(() => _adult = value ?? false),
                    title: const Text(
                      'I confirm that I am at least 18 years old.',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _terms,
                    onChanged: (value) =>
                        setState(() => _terms = value ?? false),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('I accept the '),
                        TextButton(
                          onPressed: () => context.push('/legal/terms'),
                          child: const Text('Terms of Use'),
                        ),
                        const Text(' and '),
                        TextButton(
                          onPressed: () => context.push('/legal/privacy'),
                          child: const Text('Privacy Policy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _loading ? 'Creating account…' : 'Create account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (Validators.email(_email.text) != null) {
      showMessage(context, Validators.email(_email.text)!, error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) showMessage(context, 'Password reset email sent.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your account email. We will send you a password reset link.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _send,
              child: Text(_loading ? 'Sending…' : 'Send reset email'),
            ),
          ],
        ),
      ),
    ),
  );
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;

  Future<void> _check() async {
    setState(() => _loading = true);
    try {
      final verified = await ref.read(emailVerificationRefresherProvider)();
      if (verified && mounted) {
        context.go('/');
      } else if (mounted) {
        showMessage(context, 'Email is not verified yet.', error: true);
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 68,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to $email. Open it, then return here.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase creates the sign-in account before sending this email. Until verification succeeds, FixMate blocks marketplace access, provider applications, bookings, chat, reviews, and reports.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _check,
                    child: Text(
                      _loading ? 'Checking…' : 'I have verified my email',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(authRepositoryProvider)
                          .resendVerification();
                      if (context.mounted) {
                        showMessage(context, 'Verification email sent again.');
                      }
                    },
                    child: const Text('Resend email'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(signOutActionProvider)();
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text('Use another account'),
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
