import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../config/env.dart';
import '../storage/secure_store.dart';

/// Real-time socket connection for live messaging, typing indicators, and read receipts.
class SocketService {
  sio.Socket? _socket;
  bool _connected = false;

  bool get isConnected => _connected;
  sio.Socket? get socket => _socket;

  /// Connect to the Socket.IO server with the user's auth token.
  Future<void> connect() async {
    if (_connected) return;

    final token = await SecureStore.instance.accessToken;
    if (token == null) return;

    // Derive WebSocket URL from API base (remove /api/v1 suffix)
    final baseUrl = Env.apiBaseUrl.replaceAll('/api/v1', '');

    _socket = sio.io(
      baseUrl,
      sio.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
    });

    _socket!.onDisconnect((_) {
      _connected = false;
    });

    _socket!.onConnectError((err) {
      _connected = false;
    });
  }

  /// Disconnect from the socket server.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  /// Send typing indicator for a project.
  void sendTyping(String projectId, {bool isTyping = true}) {
    _socket?.emit('typing', {'projectId': projectId, 'isTyping': isTyping});
  }

  /// Send read receipt for a report/message.
  void sendReadReceipt(String reportId, String projectId) {
    _socket?.emit('message_read', {'reportId': reportId, 'projectId': projectId});
  }

  /// Listen for new messages in any project room.
  void onNewMessage(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('new_message', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Listen for typing indicators.
  void onTyping(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('typing', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Listen for read receipts.
  void onMessageRead(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('message_read', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Remove all listeners (call on dispose).
  void removeAllListeners() {
    _socket?.off('new_message');
    _socket?.off('typing');
    _socket?.off('message_read');
  }
}

/// Global socket service provider.
final socketServiceProvider = Provider<SocketService>((ref) => SocketService());
