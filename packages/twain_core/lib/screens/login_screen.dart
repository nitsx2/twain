import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_notifier.dart';
import '../theme/tokens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.appTitle, required this.role});
  final String appTitle;
  final String role; // 'patient' | 'doctor'

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _signupMode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_signupMode) {
      await ref.read(authProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            role: widget.role,
          );
    } else {
      await ref.read(authProvider.notifier).login(
            _email.text.trim(),
            _password.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDoctor = widget.role == 'doctor';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TTokens.s7),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
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
                    ),
                    const SizedBox(height: TTokens.s5),
                    Text(
                      widget.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: TTokens.s1),
                    Text(
                      widget.role.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: TTokens.neutral500,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: TTokens.s6),
                    if (auth.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: TTokens.s3),
                        padding: const EdgeInsets.all(TTokens.s3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(TTokens.r4),
                          border: Border.all(
                            color: TTokens.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          auth.error!,
                          style: const TextStyle(
                            color: TTokens.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: TTokens.s4),
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
                          : Text(_signupMode ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: TTokens.s2),
                    TextButton(
                      onPressed: () => setState(() {
                        _signupMode = !_signupMode;
                      }),
                      child: Text(
                        _signupMode
                            ? 'Already have an account? Sign in'
                            : 'Create a new account',
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
}
