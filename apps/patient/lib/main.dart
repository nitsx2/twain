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
      child: const TwainPatientApp(),
    ),
  );
}

class TwainPatientApp extends ConsumerWidget {
  const TwainPatientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(patientRouterProvider);
    return MaterialApp.router(
      title: 'Twain AI · Patient',
      debugShowCheckedModeBanner: false,
      theme: TTheme.light(),
      routerConfig: router,
    );
  }
}
