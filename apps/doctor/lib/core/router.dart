import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

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
      final loc = state.matchedLocation;
      final atAuth = loc == '/login';
      if (!auth.isAuthenticated && !atAuth) return '/login';
      if (auth.isAuthenticated && atAuth) {
        return (auth.user?.profileComplete ?? false) ? '/home' : '/profile';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            const LoginScreen(appTitle: 'Twain AI', role: 'doctor'),
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
