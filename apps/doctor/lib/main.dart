import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain_core/twain_core.dart';

import 'core/router.dart';

const String kBackendBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:9494',
);

void main() {
  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(
          TwainApiClient.create(kBackendBaseUrl),
        ),
      ],
      child: const TwainDoctorApp(),
    ),
  );
}

class TwainDoctorApp extends ConsumerWidget {
  const TwainDoctorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(doctorRouterProvider);
    return MaterialApp.router(
      title: 'Twain AI · Doctor',
      debugShowCheckedModeBanner: false,
      theme: TTheme.light(),
      routerConfig: router,
    );
  }
}
