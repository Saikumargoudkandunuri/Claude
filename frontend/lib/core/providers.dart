import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/dio_client.dart';

/// Shared, app-wide providers.
final dioProvider = Provider<Dio>((ref) => DioClient.instance.dio);
