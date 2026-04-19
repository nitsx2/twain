import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.patientCode,
    this.profileComplete = false,
  });

  final String id;
  final String email;
  final String role; // 'patient' | 'doctor'
  final int? patientCode;
  final bool profileComplete;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        patientCode: (json['patient_code'] as num?)?.toInt(),
        profileComplete: (json['profile_complete'] as bool?) ?? false,
      );
}

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  const AuthState.initial() : this();

  final AuthUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.initial()) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    final token = await readAuthToken();
    if (token == null || token.isEmpty) return;
    try {
      final api = _ref.read(apiClientProvider);
      final resp = await api.dio.get<Map<String, dynamic>>('/api/me');
      if (resp.statusCode == 200 && resp.data != null) {
        state = state.copyWith(user: AuthUser.fromJson(resp.data!));
      } else {
        await clearAuthToken();
      }
    } catch (_) {
      await clearAuthToken();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final api = _ref.read(apiClientProvider);
      final resp = await api.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      if (resp.statusCode != 200 || resp.data == null) {
        state = state.copyWith(
          loading: false,
          error: resp.data?['detail']?.toString() ?? 'Login failed',
        );
        return;
      }
      final data = resp.data!;
      await saveAuthToken(data['access_token'] as String);
      state = state.copyWith(
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _extract(e));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final api = _ref.read(apiClientProvider);
      final resp = await api.dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {'email': email, 'password': password, 'role': role},
      );
      if (resp.statusCode != 200 && resp.statusCode != 201 || resp.data == null) {
        state = state.copyWith(
          loading: false,
          error: resp.data?['detail']?.toString() ?? 'Registration failed',
        );
        return;
      }
      final data = resp.data!;
      await saveAuthToken(data['access_token'] as String);
      state = state.copyWith(
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _extract(e));
    }
  }

  Future<void> refreshProfile() async {
    try {
      final api = _ref.read(apiClientProvider);
      final resp = await api.dio.get<Map<String, dynamic>>('/api/me');
      if (resp.statusCode == 200 && resp.data != null) {
        state = state.copyWith(user: AuthUser.fromJson(resp.data!));
      }
    } catch (_) {
      // silent
    }
  }

  Future<void> logout() async {
    await clearAuthToken();
    state = const AuthState.initial().copyWith(clearUser: true);
  }

  String _extract(Object e) {
    return e.toString();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
