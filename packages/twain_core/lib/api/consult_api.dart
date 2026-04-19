import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class ConsultApi {
  ConsultApi(this._dio);
  final Dio _dio;

  // ── Patient ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> activeConsultation() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/patient/active-consultation',
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> startConsultation() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/patient/consultations',
    );
    return r.data ?? {};
  }

  Future<void> cancelConsultation(String id) async {
    await _dio.post('/api/patient/consultations/$id/cancel');
  }

  Future<List<Map<String, dynamic>>> listPatientMessages(String id) async {
    final r = await _dio.get<List<dynamic>>(
      '/api/patient/consultations/$id/messages',
    );
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> sendPatientMessage(
    String id,
    String content,
  ) async {
    final r = await _dio.post<List<dynamic>>(
      '/api/patient/consultations/$id/messages',
      data: {'content': content},
    );
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> finalizeIntake(String id) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/patient/consultations/$id/finalize-intake',
    );
    return r.data ?? {};
  }

  // ── Doctor ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchByCode(int code) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/doctor/consultations/fetch-by-code',
      data: {'patient_code': code},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> getDoctorConsultation(String id) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/doctor/consultations/$id',
    );
    return r.data ?? {};
  }

  Future<List<Map<String, dynamic>>> listDoctorMessages(String id) async {
    final r = await _dio.get<List<dynamic>>(
      '/api/doctor/consultations/$id/messages',
    );
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> closeConsultation(String id) async {
    await _dio.post('/api/doctor/consultations/$id/close');
  }

  Future<Map<String, dynamic>> uploadRecording(
    String id,
    List<int> audioBytes, {
    String filename = 'consult.webm',
    String mimeType = 'audio/webm',
  }) async {
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/doctor/consultations/$id/recording',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return r.data ?? {};
  }

  Future<List<Map<String, dynamic>>> brainChat(
    String consultationId,
    String content,
  ) async {
    final r = await _dio.post<List<dynamic>>(
      '/api/doctor/consultations/$consultationId/brain/messages',
      data: {'content': content},
    );
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> draftRx(String consultationId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/doctor/consultations/$consultationId/rx/draft',
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> signRx(
    String consultationId,
    Map<String, dynamic> body,
  ) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/doctor/consultations/$consultationId/rx/sign',
      data: body,
    );
    return r.data ?? {};
  }

  // ── Prescriptions ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPrescriptions() async {
    final r = await _dio.get<List<dynamic>>('/api/prescriptions');
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listPatientConsultations() async {
    final r = await _dio.get<List<dynamic>>('/api/patient/consultations');
    return (r.data ?? []).cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listDoctorConsultations() async {
    final r = await _dio.get<List<dynamic>>('/api/doctor/consultations');
    return (r.data ?? []).cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Uint8List> getPdfBytes(String prescriptionId) async {
    final r = await _dio.get<List<int>>(
      '/api/prescriptions/$prescriptionId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList((r.data ?? const []).cast<int>());
  }
}

final consultApiProvider = Provider<ConsultApi>((ref) {
  return ConsultApi(ref.read(apiClientProvider).dio);
});

final activeConsultationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(consultApiProvider).activeConsultation();
});

/// Patient-visible messages for a consultation.
final patientMessagesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  return ref.read(consultApiProvider).listPatientMessages(id);
});

/// Full doctor-side consultation detail (intake summary + patient bio).
final doctorConsultProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(consultApiProvider).getDoctorConsultation(id);
});

/// All messages for a consultation — doctor-side (no visibility filter).
final doctorMessagesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  return ref.read(consultApiProvider).listDoctorMessages(id);
});

/// Current user's prescriptions list.
final prescriptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultApiProvider).listPrescriptions();
});

/// All consultations for patient (history).
final patientConsultationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultApiProvider).listPatientConsultations();
});

/// All consultations for doctor (history).
final doctorConsultationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultApiProvider).listDoctorConsultations();
});
