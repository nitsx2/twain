import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

import '../features/consult/consultation_history_screen.dart';
import '../features/consult/patient_consult_screen.dart';
import '../features/home/patient_home_screen.dart';
import '../features/prescription/prescriptions_list_screen.dart';
import '../features/prescription/rx_viewer_screen.dart';
import '../features/profile/patient_profile_screen.dart';

final patientRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  return GoRouter(
    refreshListenable: listenable,
    initialLocation: '/home',
    redirect: (_, state) {
      final auth = ref.read(authProvider);
      if (auth.bootstrapping) return '/splash';
      final loc = state.matchedLocation;
      final atAuth = loc == '/login' || loc == '/signup' || loc == '/splash';
      if (!auth.isAuthenticated && !atAuth) return '/login';
      if (auth.isAuthenticated && atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const AuthSplash(role: 'patient'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const SignInScreen(role: 'patient'),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignUpScreen(role: 'patient'),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const PatientHomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const PatientProfileScreen(),
      ),
      GoRoute(
        path: '/consult/:id',
        builder: (_, s) => PatientConsultScreen(
          consultationId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/prescriptions',
        builder: (_, __) => const PrescriptionsListScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const ConsultationHistoryScreen(),
      ),
      GoRoute(
        path: '/prescription/:id',
        builder: (_, s) => RxViewerScreen(
          prescriptionId: s.pathParameters['id']!,
        ),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
