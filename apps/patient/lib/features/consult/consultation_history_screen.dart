import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twain_core/twain_core.dart';

class ConsultationHistoryScreen extends ConsumerWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(patientConsultationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(patientConsultationsProvider),
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
                  title: 'No consultations yet',
                  message:
                      'After you start your first consultation, it will appear here.',
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
                final status = c['status'] as String? ?? 'intake_pending';
                final createdAt = c['created_at'] as String?;
                final closedAt = c['closed_at'] as String?;
                final dateStr = closedAt != null
                    ? DateFormat('d MMM yyyy')
                        .format(DateTime.parse(closedAt).toLocal())
                    : createdAt != null
                        ? DateFormat('d MMM yyyy')
                            .format(DateTime.parse(createdAt).toLocal())
                        : '';
                final isClosed = status == 'closed';
                final (Color chipBg, Color chipFg, String chipLabel) =
                    switch (status) {
                  'closed' => (
                      TTokens.primary50,
                      TTokens.primary900,
                      'Completed'
                    ),
                  'in_consultation' => (
                      TTokens.ai50,
                      TTokens.ai600,
                      'With Doctor'
                    ),
                  'intake_done' => (
                      const Color(0xFFFFF8E1),
                      const Color(0xFFE65100),
                      'Ready'
                    ),
                  _ => (TTokens.neutral100, TTokens.neutral600, 'In Progress'),
                };
                return TCard(
                  onTap: isClosed ? null : () => context.push('/consult/$cid'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: TTokens.primary50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_services_outlined,
                            color: TTokens.primary900, size: 22),
                      ),
                      const SizedBox(width: TTokens.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(chipLabel,
                                      style: TextStyle(
                                          color: chipFg,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(dateStr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: TTokens.neutral500)),
                            ],
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
