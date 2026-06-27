import 'package:dio/dio.dart';

import '../../../core/network/customer_dio_client.dart';

/// Thin HTTP layer for customer portal data endpoints.
///
/// All endpoints require customer authentication — the [CustomerDioClient]
/// interceptor attaches the Bearer token automatically.
class CustomerApi {
  CustomerApi(this._dio);
  final Dio _dio;

  /// Convenience factory using the singleton [CustomerDioClient].
  factory CustomerApi.withClient() =>
      CustomerApi(CustomerDioClient.instance.dio);

  /// Fetch whitelisted project overview for the authenticated customer.
  Future<Map<String, dynamic>> getOverview() async {
    final res = await _dio.get('/customer/overview');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Fetch the 13-stage timeline for the customer's project.
  Future<List<dynamic>> getTimeline() async {
    final res = await _dio.get('/customer/timeline');
    return res.data['data'] as List<dynamic>;
  }

  /// Fetch project photos (newest first).
  Future<List<dynamic>> getPhotos() async {
    final res = await _dio.get('/customer/photos');
    return res.data['data'] as List<dynamic>;
  }

  /// Fetch approved drawings only.
  Future<List<dynamic>> getDrawings() async {
    final res = await _dio.get('/customer/drawings');
    return res.data['data'] as List<dynamic>;
  }

  /// Fetch payment summary: quotationAmount, totalReceived, outstandingBalance.
  Future<Map<String, dynamic>> getPaymentSummary() async {
    final res = await _dio.get('/customer/payments');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Fetch customer notifications (newest first).
  Future<List<dynamic>> getNotifications() async {
    final res = await _dio.get('/customer/notifications');
    return res.data['data'] as List<dynamic>;
  }

  /// Mark a single notification as read.
  Future<void> markNotificationRead(String id) async {
    await _dio.put('/customer/notifications/$id/read');
  }

  /// Fetch admin announcements/messages (newest first).
  Future<List<dynamic>> getMessages() async {
    final res = await _dio.get('/customer/messages');
    return res.data['data'] as List<dynamic>;
  }
}
