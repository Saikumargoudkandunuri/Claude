import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Fetches the role-specific dashboard payload from the API.
final dashboardProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, role) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/dashboard/$role');
  return res.data['data'] as Map<String, dynamic>;
});
