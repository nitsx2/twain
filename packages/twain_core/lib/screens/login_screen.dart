import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_notifier.dart';
import '../theme/tokens.dart';

/// Scaffolded sign-in / sign-up container with shared branding.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String role;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDoctor = role == 'doctor';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TTokens.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDoctor
                              ? [TTokens.primary700, TTokens.primary900]
                              : [TTokens.ai400, TTokens.ai600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: TTokens.shadowMd,
                      ),
                      child: Icon(
                        isDoctor
                            ? Icons.medical_services_outlined
                            : Icons.auto_awesome,
                        color: TTokens.neutral0,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: TTokens.s4),
                  Text(
                    'Twain AI',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    role.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: TTokens.neutral500,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: TTokens.s6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: TTokens.neutral600,
                        ),
                  ),
                  const SizedBox(height: TTokens.s5),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _errorBanner(BuildContext context, String? error) {
  if (error == null) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(bottom: TTokens.s3),
    padding: const EdgeInsets.all(TTokens.s3),
    decoration: BoxDecoration(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(TTokens.r4),
      border: Border.all(color: TTokens.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: TTokens.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            error,
            style: const TextStyle(color: TTokens.danger, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// ────────────────────────────────────────────────────────────────────────
/// Sign in
/// ────────────────────────────────────────────────────────────────────────
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.role});
  final String role;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          _email.text.trim(),
          _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return _AuthScaffold(
      role: widget.role,
      title: 'Welcome back',
      subtitle: widget.role == 'doctor'
          ? 'Sign in to see your consultations.'
          : 'Sign in to continue your care.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _errorBanner(context, auth.error),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: TTokens.s3),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Min 6 characters'
                  : null,
            ),
            const SizedBox(height: TTokens.s5),
            FilledButton(
              onPressed: auth.loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: TTokens.primary900,
                padding: const EdgeInsets.symmetric(vertical: TTokens.s4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TTokens.r4),
                ),
              ),
              child: auth.loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: TTokens.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: TTokens.neutral600),
                ),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Create one',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Sign up
/// ────────────────────────────────────────────────────────────────────────
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, required this.role});
  final String role;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          role: widget.role,
          firstName: _first.text.trim().isEmpty ? null : _first.text.trim(),
          lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return _AuthScaffold(
      role: widget.role,
      title: 'Create your account',
      subtitle: 'A few details and you\'re in.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _errorBanner(context, auth.error),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: TTokens.s2),
                Expanded(
                  child: TextFormField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: TTokens.s3),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: TTokens.s3),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? 'Enter a valid phone'
                  : null,
            ),
            const SizedBox(height: TTokens.s3),
            TextFormField(
              controller: _password,
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Password (min 6)',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Min 6 characters'
                  : null,
            ),
            const SizedBox(height: TTokens.s5),
            FilledButton(
              onPressed: auth.loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: TTokens.primary900,
                padding: const EdgeInsets.symmetric(vertical: TTokens.s4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TTokens.r4),
                ),
              ),
              child: auth.loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: TTokens.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(color: TTokens.neutral600),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sign in',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash shown during the initial auth bootstrap so a page refresh doesn't
/// flash the login screen before the stored token is validated.
class AuthSplash extends StatelessWidget {
  const AuthSplash({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isDoctor = role == 'doctor';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDoctor
                        ? [TTokens.primary700, TTokens.primary900]
                        : [TTokens.ai400, TTokens.ai600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: TTokens.shadowLg,
                ),
                child: Icon(
                  isDoctor
                      ? Icons.medical_services_outlined
                      : Icons.auto_awesome,
                  color: TTokens.neutral0,
                  size: 40,
                ),
              ),
              const SizedBox(height: TTokens.s5),
              Text('Twain AI',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: TTokens.s6),
              const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: TTokens.primary900,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
