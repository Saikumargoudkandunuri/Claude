import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';

/// Background message handler (must be top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Global navigator key for routing on notification tap.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Notification plugin instance.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission explicitly for Android 13+.
  // This ensures the permission dialog shows even without Firebase.
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (_) {}

  // Firebase init — safe to call even if no google-services.json yet (dev mode).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Create Android notification channel.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'icms_default',
      'ICMS Notifications',
      description: 'Interior Company Management System alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize local notifications.
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null &&
            payload.isNotEmpty &&
            navigatorKey.currentContext != null) {
          GoRouter.of(navigatorKey.currentContext!).push(payload);
        }
      },
    );

    // Request permission (iOS + Android 13+).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground: show local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      flutterLocalNotificationsPlugin.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFF6C63FF),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['route'],
      );
    });

    // Notification tap → navigate (app in background).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['route'];
      if (route != null &&
          route.toString().isNotEmpty &&
          navigatorKey.currentContext != null) {
        GoRouter.of(navigatorKey.currentContext!).push(route.toString());
      }
    });

    // Notification tap → navigate (app was terminated).
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = initialMessage.data['route'];
        if (route != null &&
            route.toString().isNotEmpty &&
            navigatorKey.currentContext != null) {
          GoRouter.of(navigatorKey.currentContext!).push(route.toString());
        }
      });
    }
  } catch (_) {
    // Firebase not configured yet — app still works without push.
  }

  runApp(ProviderScope(child: ICMSApp(navigatorKey: navigatorKey)));
}
