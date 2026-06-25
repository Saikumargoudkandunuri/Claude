import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> get(String projectId) async {
    final res = await _dio.get('/projects/$projectId/payments');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> addHistory(String projectId, Map<String, dynamic> body) async {
    await _dio.post('/projects/$projectId/payments/history', data: body);
  }

  /// Record a partial received payment (validates amount <= balance on server).
  Future<void> addReceived(String projectId, Map<String, dynamic> body) async {
    await _dio.post('/projects/$projectId/payments/received', data: body);
  }

  Future<void> updateHistory(String historyId, Map<String, dynamic> body) async {
    await _dio.put('/payments/history/$historyId', data: body);
  }

  Future<void> deleteHistory(String historyId) async {
    await _dio.delete('/payments/history/$historyId');
  }

  Future<void> clearBalance(String projectId, {String? method, String? reference}) async {
    await _dio.post('/projects/$projectId/payments/clear', data: {
      if (method != null) 'method': method,
      if (reference != null) 'referenceNumber': reference,
    },);
  }

  Future<void> updateQuotation(String projectId, num amount) async {
    await _dio.put('/projects/$projectId/payments', data: {'quotationAmount': amount});
  }
}

final paymentsRepositoryProvider =
    Provider<PaymentsRepository>((ref) => PaymentsRepository(ref.watch(dioProvider)));

final projectPaymentsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, projectId) async {
  return ref.watch(paymentsRepositoryProvider).get(projectId);
});
