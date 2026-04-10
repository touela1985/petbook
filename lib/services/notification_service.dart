import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'profile_service.dart';

// Must be a top-level function — called by FCM when app is terminated/background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are displayed automatically by FCM.
  // No extra action needed for MVP.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ProfileService _profileService = ProfileService();

  static const _channelId = 'petbook_default_channel';
  static const _channelName = 'Petbook Notifications';

  Future<void> initialize() async {
    // Register the background message handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Request notification permission (required on iOS; Android 13+).
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. On iOS, show notifications while the app is in the foreground.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Set up flutter_local_notifications (foreground display on both platforms).
    await _setupLocalNotifications();

    // 4. Save token immediately when auth state becomes logged-in.
    //    Covers: app restart with existing session + fresh login.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _fcm.getToken();
        if (token != null) await _saveToken(token);
      }
    });

    // 5. Token refresh listener — FCM may rotate the token at any time.
    //    Only saves if a user is currently logged in.
    _fcm.onTokenRefresh.listen((newToken) async {
      if (FirebaseAuth.instance.currentUser != null) {
        await _saveToken(newToken);
      }
    });

    // 6. Foreground message handler — show a local notification banner.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) _showLocalNotification(notification);
    });
  }

  // ─── Local notifications setup ───────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android requires an explicit notification channel (API 26+).
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _showLocalNotification(RemoteNotification notification) {
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ─── Debug helpers (temporary — remove after testing) ────────────────────

  /// Returns the current FCM token and prints it to console.
  Future<String?> debugGetAndPrintToken() async {
    final token = await _fcm.getToken();
    // ignore: avoid_print
    print('[FCM DEBUG] token: $token');
    return token;
  }

  /// Shows an immediate local notification to verify the channel works.
  Future<void> debugShowTestNotification() async {
    await _localNotifications.show(
      999,
      'Petbook — Test',
      'Οι notifications λειτουργούν!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ─── Token persistence ────────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    await _profileService.saveFcmToken(token);
  }
}
