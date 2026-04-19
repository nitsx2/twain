import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class ProfileApi {
  ProfileApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getPatient() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/profile/patient');
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> updatePatient(Map<String, dynamic> body) async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/api/profile/patient',
      data: body,
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> getDoctor() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/profile/doctor');
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> updateDoctor(Map<String, dynamic> body) async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/api/profile/doctor',
      data: body,
    );
    return r.data ?? {};
  }

  Future<void> uploadSignature(Uint8List bytes) async {
    final form = FormData.fromMap({
      'signature':
          MultipartFile.fromBytes(bytes, filename: 'signature.png'),
    });
    await _dio.post(
      '/api/profile/doctor/signature',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.read(apiClientProvider).dio);
});
