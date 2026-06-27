import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_api.dart';

/// Provides a [CustomerApi] instance backed by the singleton [CustomerDioClient].
final customerApiProvider =
    Provider<CustomerApi>((ref) => CustomerApi.withClient());

/// Customer project overview (whitelisted fields only).
final customerOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getOverview();
});

/// Customer 13-stage project timeline.
final customerTimelineProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getTimeline();
});

/// Customer project photos (newest first).
final customerPhotosProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getPhotos();
});

/// Customer approved drawings only.
final customerDrawingsProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getDrawings();
});

/// Customer payment summary (totals only, no transaction details).
final customerPaymentSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getPaymentSummary();
});

/// Customer notifications list.
final customerNotificationsProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getNotifications();
});

/// Customer messages (admin announcements).
final customerMessagesProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getMessages();
});
