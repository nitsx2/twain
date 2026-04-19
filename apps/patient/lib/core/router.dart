import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

import '../features/consult/patient_consult_screen.dart';
import '../features/home/patient_home_screen.dart';
import '../features/profile/patient_profile_screen.dart';

final patientRouterProvider = Provider<GoRouter>((ref) {
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
            const LoginScreen(appTitle: 'Twain AI', role: 'patient'),
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
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
