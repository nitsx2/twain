import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twain_core/twain_core.dart';

class PrescriptionsListScreen extends ConsumerWidget {
  const PrescriptionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(prescriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(prescriptionsProvider),
        child: list.when(
          loading: () => const TLoading(message: 'Loading prescriptions…'),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(TTokens.s5),
            child: Text('$e', style: const TextStyle(color: TTokens.danger)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  TEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No prescriptions yet',
                    message:
                        'After your doctor signs a prescription, it will appear here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(TTokens.s5),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: TTokens.s3),
              itemBuilder: (_, i) {
                final p = items[i];
                final pid = p['id'] as String;
                final signedAt = p['signed_at'] as String?;
                final items0 = (p['items'] as Map<String, dynamic>?)?['medicines'] as List?;
                final medCount = items0?.length ?? 0;
                final doctorName = p['doctor_name'] as String? ?? 'Doctor';
                final dateStr = signedAt != null
                    ? DateFormat('d MMM yyyy, h:mm a')
                        .format(DateTime.parse(signedAt).toLocal())
                    : '';
                return TCard(
                  onTap: () => context.push('/prescription/$pid'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$medCount ${medCount == 1 ? "medicine" : "medicines"}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            Text(
                              doctorName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: TTokens.neutral500),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: TTokens.neutral400),
                              ),
                          ],
                        ),
                      ),
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
