import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers.dart';

/// Manages offline message caching and background sync.
/// - Caches received messages locally for offline reading
/// - Queues outgoing messages when offline
/// - Syncs queued messages when connectivity resumes
class OfflineSyncService {
  OfflineSyncService(this._ref);
  final Ref _ref;

  static const _messagesBoxName = 'cached_messages';
  static const _queueBoxName = 'message_queue';

  Box<String>? _messagesBox;
  Box<String>? _queueBox;
  StreamSubscription? _connectivitySub;
  bool _syncing = false;

  /// Initialize Hive boxes and start listening to connectivity.
  Future<void> init() async {
    _messagesBox = await Hive.openBox<String>(_messagesBoxName);
    _queueBox = await Hive.openBox<String>(_queueBoxName);

    // Listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncQueue();
      }
    });
  }

  /// Cache messages for a project (for offline reading).
  void cacheMessages(String projectId, List<Map<String, dynamic>> messages) {
    _messagesBox?.put(projectId, jsonEncode(messages));
  }

  /// Get cached messages for a project (when offline).
  List<Map<String, dynamic>> getCachedMessages(String projectId) {
    final data = _messagesBox?.get(projectId);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Queue a message for sending when offline.
  Future<void> queueMessage({
    required String projectId,
    required Map<String, dynamic> body,
  }) async {
    final entry = jsonEncode({
      'projectId': projectId,
      'body': body,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await _queueBox?.add(entry);
  }

  /// Get pending queue count.
  int get pendingCount => _queueBox?.length ?? 0;

  /// Sync all queued messages to the server.
  Future<void> syncQueue() async {
    if (_syncing || (_queueBox?.isEmpty ?? true)) return;
    _syncing = true;

    try {
      final dio = _ref.read(dioProvider);
      final keys = _queueBox!.keys.toList();

      for (final key in keys) {
        final raw = _queueBox!.get(key);
        if (raw == null) continue;

        try {
          final entry = jsonDecode(raw) as Map<String, dynamic>;
          final projectId = entry['projectId'] as String;
          final body = entry['body'] as Map<String, dynamic>;

          await dio.post('/projects/$projectId/reports', data: body);
          await _queueBox!.delete(key);
        } catch (e) {
          if (e is DioException && e.response?.statusCode != null) {
            // Server error — remove from queue to avoid infinite retry
            if (e.response!.statusCode! >= 400 &&
                e.response!.statusCode! < 500) {
              await _queueBox!.delete(key);
            }
          }
          // Network error — stop trying, will retry on next connectivity event
          break;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  /// Check if device is currently online.
  Future<bool> get isOnline async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}

/// Provider for the offline sync service.
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(ref);
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider that exposes current connectivity state as a stream.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
});
