import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final active = ref.watch(activeConsultationProvider);
    final code = user?.patientCode;

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
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(activeConsultationProvider),
        child: ListView(
          padding: const EdgeInsets.all(TTokens.s5),
          children: [
            _CodeCard(code: code),
            const SizedBox(height: TTokens.s5),
            active.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: TTokens.s8),
                child: TLoading(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: TTokens.s4),
                child: Text('$e',
                    style: const TextStyle(color: TTokens.danger)),
              ),
              data: (data) {
                final isActive = data['active'] == true;
                if (!isActive) {
                  return _StartCard(
                    onStart: () async {
                      try {
                        final resp = await ref
                            .read(consultApiProvider)
                            .startConsultation();
                        ref.invalidate(activeConsultationProvider);
                        final id = resp['id'] as String?;
                        if (id != null && context.mounted) {
                          context.push('/consult/$id');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not start: $e')),
                          );
                        }
                      }
                    },
                  );
                }
                return _ActiveCard(
                  consult: data['consultation'] as Map<String, dynamic>?,
                );
              },
            ),
            const SizedBox(height: TTokens.s5),
            TCard(
              onTap: () => context.push('/prescriptions'),
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
                      Icons.receipt_long_outlined,
                      color: TTokens.primary900,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: TTokens.s4),
                  Expanded(
                    child: Text(
                      'My prescriptions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: TTokens.neutral400),
                ],
              ),
            ),
            const SizedBox(height: TTokens.s3),
            TCard(
              onTap: () => context.push('/history'),
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
                      Icons.history,
                      color: TTokens.primary900,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: TTokens.s4),
                  Expanded(
                    child: Text(
                      'Consultation history',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: TTokens.neutral400),
                ],
              ),
            ),
            const SizedBox(height: TTokens.s3),
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
                        Text('My profile',
                            style:
                                Theme.of(context).textTheme.titleMedium),
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
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({this.code});
  final int? code;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'YOUR PATIENT CODE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: TTokens.neutral0.withValues(alpha: 0.75),
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: TTokens.s3),
          Text(
            code?.toString() ?? '----',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: TTokens.neutral0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                  fontSize: 68,
                ),
          ),
          const SizedBox(height: TTokens.s3),
          Text(
            'Share this code with your doctor at the clinic.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: TTokens.neutral0.withValues(alpha: 0.9),
                ),
          ),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(TTokens.r6),
      child: Container(
        padding: const EdgeInsets.all(TTokens.s6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TTokens.r6),
          gradient: const LinearGradient(
            colors: [TTokens.ai400, TTokens.ai600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: TTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: TTokens.neutral0,
                  size: 28,
                ),
                const SizedBox(width: TTokens.s3),
                Expanded(
                  child: Text(
                    'Start a new consultation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: TTokens.neutral0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TTokens.s2),
            Text(
              "Twain AI will ask about your symptoms, then hand the details to your doctor when you arrive at the clinic.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TTokens.neutral0.withValues(alpha: 0.9),
                  ),
            ),
            const SizedBox(height: TTokens.s5),
            const Row(
              children: [
                Text(
                  'BEGIN INTAKE',
                  style: TextStyle(
                    color: TTokens.neutral0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: TTokens.s2),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: TTokens.neutral0,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.consult});
  final Map<String, dynamic>? consult;

  @override
  Widget build(BuildContext context) {
    final status = (consult?['status'] as String?) ?? 'intake_pending';
    final id = consult?['id'] as String?;
    final (String title, String msg, IconData icon) = switch (status) {
      'intake_pending' => (
          'Intake in progress',
          'Continue your chat with Twain AI.',
          Icons.chat_bubble_outline_rounded,
        ),
      'intake_done' => (
          'Ready for the doctor',
          'Share your code at the clinic — the doctor will pick you up.',
          Icons.check_circle_outline_rounded,
        ),
      'in_consultation' => (
          'With your doctor',
          'Your doctor has started the consultation.',
          Icons.medical_services_outlined,
        ),
      _ => ('Active consultation', '', Icons.info_outline),
    };
    return InkWell(
      onTap: id != null
          ? () => GoRouter.of(context).push('/consult/$id')
          : null,
      borderRadius: BorderRadius.circular(TTokens.r6),
      child: Container(
        padding: const EdgeInsets.all(TTokens.s5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TTokens.r6),
          color: TTokens.ai50,
          border: Border.all(color: TTokens.ai200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: TTokens.ai500,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: TTokens.neutral0, size: 22),
            ),
            const SizedBox(width: TTokens.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (msg.isNotEmpty)
                    Text(
                      msg,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: TTokens.neutral600,
                          ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TTokens.neutral400),
          ],
        ),
      ),
    );
  }
}
