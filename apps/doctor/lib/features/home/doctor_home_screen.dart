import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});
  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  final _code = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _code.text.trim();
    if (text.length != 4 || int.tryParse(text) == null) {
      setState(() => _error = 'Enter a 4-digit patient code');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(consultApiProvider).fetchByCode(int.parse(text));
      final id = data['consultation_id'] as String;
      final name = data['patient_name'] as String?;
      final code = (data['patient_code'] as num?)?.toInt();
      if (!mounted) return;
      _code.clear();
      context.push(
        '/consult/$id',
        extra: {'patient_name': name, 'patient_code': code},
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString() ??
              'Could not fetch patient'
          : 'Could not fetch: ${e.message}';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twain AI'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TTokens.s5),
        children: [
          Container(
            padding: const EdgeInsets.all(TTokens.s6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TTokens.r6),
              gradient: const LinearGradient(
                colors: [TTokens.primary800, TTokens.primary950],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: TTokens.shadowMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: TTokens.neutral0.withValues(alpha: 0.75),
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: TTokens.s2),
                Text(
                  user?.email ?? 'Doctor',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: TTokens.neutral0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: TTokens.s2),
                Text(
                  "Enter a patient's 4-digit code to open their consultation.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: TTokens.neutral0.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TTokens.s5),
          Container(
            padding: const EdgeInsets.all(TTokens.s5),
            decoration: BoxDecoration(
              color: TTokens.neutral0,
              borderRadius: BorderRadius.circular(TTokens.r6),
              border: Border.all(color: TTokens.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PATIENT CODE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: TTokens.neutral500,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: TTokens.s3),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 16,
                    color: TTokens.primary900,
                  ),
                  decoration: InputDecoration(
                    hintText: '----',
                    hintStyle: const TextStyle(
                      color: TTokens.neutral300,
                      letterSpacing: 16,
                    ),
                    filled: true,
                    fillColor: TTokens.neutral50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TTokens.r5),
                      borderSide: const BorderSide(color: TTokens.neutral200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TTokens.r5),
                      borderSide: const BorderSide(color: TTokens.neutral200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TTokens.r5),
                      borderSide: const BorderSide(
                        color: TTokens.primary900,
                        width: 1.5,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: TTokens.s3),
                  Text(_error!,
                      style: const TextStyle(color: TTokens.danger)),
                ],
                const SizedBox(height: TTokens.s4),
                TButton(
                  label: 'Open consultation',
                  onPressed: _submit,
                  loading: _submitting,
                  fullWidth: true,
                  size: TButtonSize.lg,
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: TTokens.s5),
          TCard(
            onTap: () => context.push('/profile'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: TTokens.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: TTokens.primary900,
                    size: 22,
                  ),
                ),
                const SizedBox(width: TTokens.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My profile & signature',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: TTokens.neutral500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: TTokens.neutral400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
