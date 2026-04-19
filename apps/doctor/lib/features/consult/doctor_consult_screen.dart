import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

class DoctorConsultScreen extends ConsumerWidget {
  const DoctorConsultScreen({
    super.key,
    required this.consultationId,
    this.patientName,
    this.patientCode,
  });
  final String consultationId;
  final String? patientName;
  final int? patientCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(doctorConsultProvider(consultationId));
    final messages = ref.watch(doctorMessagesProvider(consultationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.stop_circle_outlined,
                color: TTokens.danger),
            label: const Text('Close',
                style: TextStyle(color: TTokens.danger)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Close consultation?'),
                  content: const Text(
                    'This ends the consultation. The patient can then start a new one.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: TTokens.danger,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ref
                      .read(consultApiProvider)
                      .closeConsultation(consultationId);
                  if (context.mounted) context.go('/home');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: detail.when(
        loading: () => const TLoading(message: 'Loading consultation…'),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(TTokens.s5),
          child: Text('$e', style: const TextStyle(color: TTokens.danger)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(doctorConsultProvider(consultationId));
            ref.invalidate(doctorMessagesProvider(consultationId));
          },
          child: ListView(
            padding: const EdgeInsets.all(TTokens.s5),
            children: [
              _PatientHeader(detail: d, fallbackName: patientName),
              const SizedBox(height: TTokens.s5),
              _IntakeSummaryCard(summary: d['intake_summary'] as Map<String, dynamic>?),
              const SizedBox(height: TTokens.s5),
              _SectionLabel(text: 'Intake conversation'),
              const SizedBox(height: TTokens.s2),
              messages.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: TTokens.s6),
                  child: TLoading(),
                ),
                error: (e, _) => Text('$e',
                    style: const TextStyle(color: TTokens.danger)),
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return const TEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                    );
                  }
                  return Column(
                    children: [
                      for (final m in msgs)
                        _msgBubble(context, m),
                    ],
                  );
                },
              ),
              const SizedBox(height: TTokens.s6),
              _SectionLabel(text: 'Recording'),
              const SizedBox(height: TTokens.s2),
              const TEmptyState(
                icon: Icons.mic_outlined,
                title: 'Mic + transcription land in the next build',
                message:
                    "Press record to capture the live consultation; Qubrid transcribes and Claude summarises.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _msgBubble(BuildContext context, Map<String, dynamic> m) {
    final role = m['sender_role'] as String? ?? 'system';
    final content = m['content'] as String? ?? '';
    final TChatRole r;
    final String? label;
    switch (role) {
      case 'patient':
        r = TChatRole.user;
        label = 'Patient';
        break;
      case 'twain_ai':
        r = TChatRole.ai;
        label = 'Twain AI';
        break;
      case 'doctor':
        r = TChatRole.doctor;
        label = 'You';
        break;
      case 'brain_ai':
        r = TChatRole.ai;
        label = 'Brain';
        break;
      default:
        r = TChatRole.system;
        label = null;
    }
    return TChatBubble(
      role: r,
      senderLabel: label,
      child: Text(content.isEmpty ? '(structured payload)' : content),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.detail, this.fallbackName});
  final Map<String, dynamic> detail;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final name = (detail['patient_name'] as String?) ??
        fallbackName ??
        'Patient';
    final code = (detail['patient_code'] as num?)?.toInt();
    final sex = detail['patient_sex'] as String?;
    final dob = detail['patient_dob'] as String?;
    return Container(
      padding: const EdgeInsets.all(TTokens.s5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TTokens.r6),
        gradient: const LinearGradient(
          colors: [TTokens.primary800, TTokens.primary950],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: TTokens.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 26),
          ),
          const SizedBox(width: TTokens.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (code != null) 'Code $code',
                    if (sex != null && sex.isNotEmpty) sex,
                    if (dob != null) dob,
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeSummaryCard extends StatelessWidget {
  const _IntakeSummaryCard({this.summary});
  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return TCard(
        child: Row(
          children: const [
            Icon(Icons.hourglass_top_rounded, color: TTokens.neutral400),
            SizedBox(width: TTokens.s3),
            Expanded(
              child: Text(
                'Intake summary not available yet.',
                style: TextStyle(color: TTokens.neutral600),
              ),
            ),
          ],
        ),
      );
    }
    final s = summary!;
    final chief = (s['chief_complaint'] as String?) ?? '';
    final onset = (s['onset'] as String?) ?? '';
    final duration = (s['duration'] as String?) ?? '';
    final severity = s['severity_1_10'];
    final assoc = (s['associated_symptoms'] as List?)?.cast<String>() ?? const [];
    final history = (s['history'] as String?) ?? '';
    final meds = (s['current_medications'] as List?)?.cast<String>() ?? const [];
    final allergies = (s['allergies'] as List?)?.cast<String>() ?? const [];
    final redFlags = (s['red_flags'] as List?)?.cast<String>() ?? const [];
    final summaryText = (s['patient_summary'] as String?) ?? '';

    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(
                  color: TTokens.ai50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: TTokens.ai600, size: 16),
              ),
              const SizedBox(width: TTokens.s2),
              Text(
                'AI INTAKE SUMMARY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TTokens.ai700,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: TTokens.s3),
          if (chief.isNotEmpty)
            _row('Chief complaint', chief, bold: true),
          if (onset.isNotEmpty) _row('Onset', onset),
          if (duration.isNotEmpty) _row('Duration', duration),
          if (severity != null) _row('Severity', '$severity / 10'),
          if (assoc.isNotEmpty)
            _row('Associated', assoc.join(', ')),
          if (history.isNotEmpty) _row('History', history),
          if (meds.isNotEmpty) _row('Current meds', meds.join(', ')),
          if (allergies.isNotEmpty) _row('Allergies', allergies.join(', ')),
          if (redFlags.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: TTokens.s3),
              padding: const EdgeInsets.all(TTokens.s3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(TTokens.r4),
                border: Border.all(color: TTokens.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: TTokens.danger, size: 18),
                  const SizedBox(width: TTokens.s2),
                  Expanded(
                    child: Text(
                      'Red flags: ${redFlags.join('; ')}',
                      style: const TextStyle(
                        color: TTokens.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (summaryText.isNotEmpty) ...[
            const SizedBox(height: TTokens.s4),
            const Divider(height: 1),
            const SizedBox(height: TTokens.s3),
            Text(summaryText, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TTokens.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: TTokens.neutral500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: TTokens.neutral900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: TTokens.neutral500,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
