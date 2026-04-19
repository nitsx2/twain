import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

import '../features/consult/doctor_history_screen.dart';
import '../features/consult/doctor_consult_screen.dart';
import '../features/home/doctor_home_screen.dart';
import '../features/profile/doctor_profile_screen.dart';

final doctorRouterProvider = Provider<GoRouter>((ref) {
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
        builder: (_, __) => const AuthSplash(role: 'doctor'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const SignInScreen(role: 'doctor'),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignUpScreen(role: 'doctor'),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const DoctorHomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const DoctorProfileScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const DoctorHistoryScreen(),
      ),
      GoRoute(
        path: '/consult/:id',
        builder: (_, s) {
          final id = s.pathParameters['id']!;
          final extra = s.extra as Map<String, dynamic>?;
          return DoctorConsultScreen(
            consultationId: id,
            patientName: extra?['patient_name'] as String?,
            patientCode: (extra?['patient_code'] as num?)?.toInt(),
          );
        },
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
