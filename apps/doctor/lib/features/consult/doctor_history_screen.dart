import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twain_core/twain_core.dart';

class DoctorHistoryScreen extends ConsumerWidget {
  const DoctorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(doctorConsultationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(doctorConsultationsProvider),
        child: list.when(
          loading: () => const TLoading(message: 'Loading history…'),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(TTokens.s5),
            child: Text('$e', style: const TextStyle(color: TTokens.danger)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                TEmptyState(
                  icon: Icons.history,
                  title: 'No past consultations',
                  message:
                      'Closed consultations with patients will appear here.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(TTokens.s5),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: TTokens.s3),
              itemBuilder: (_, i) {
                final c = items[i];
                final cid = c['id'] as String;
                final status = c['status'] as String? ?? '';
                final patientName =
                    c['patient_name'] as String? ?? 'Patient';
                final patientCode = c['patient_code'] as int?;
                final diagnosis = c['diagnosis'] as String?;
                final closedAt = c['closed_at'] as String?;
                final startedAt = c['started_at'] as String?;
                final dateStr = closedAt != null
                    ? DateFormat('d MMM yyyy')
                        .format(DateTime.parse(closedAt).toLocal())
                    : startedAt != null
                        ? DateFormat('d MMM yyyy')
                            .format(DateTime.parse(startedAt).toLocal())
                        : '';
                final isClosed = status == 'closed';
                return TCard(
                  onTap: isClosed
                      ? null
                      : () => context.push('/consult/$cid', extra: {
                            'patient_name': patientName,
                            'patient_code': patientCode,
                          }),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: TTokens.primary50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline,
                            color: TTokens.primary900, size: 22),
                      ),
                      const SizedBox(width: TTokens.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patientName,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            if (patientCode != null)
                              Text('Code: $patientCode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: TTokens.neutral500)),
                            if (diagnosis != null && diagnosis.isNotEmpty)
                              Text(
                                diagnosis,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: TTokens.neutral600),
                              ),
                            if (dateStr.isNotEmpty)
                              Text(dateStr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: TTokens.neutral400)),
                          ],
                        ),
                      ),
                      if (!isClosed)
                        const Icon(Icons.chevron_right,
                            color: TTokens.neutral400),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
