import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/pet_health_event.dart';
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

  // ─── Notification tap state ──────────────────────────────────────────────

  /// Stores the tap data when the app was launched from a terminated state
  /// by tapping a notification. Consumed once by MainNavigation.
  Map<String, String>? _pendingTap;

  /// Broadcasts tap events when the app is in background or foreground.
  final StreamController<Map<String, String>> _tapController =
      StreamController<Map<String, String>>.broadcast();

  /// Returns and clears the pending tap (terminated-app case).
  /// Call once from MainNavigation.initState().
  Map<String, String>? consumePendingTap() {
    final data = _pendingTap;
    _pendingTap = null;
    return data;
  }

  /// Stream of notification taps for background and foreground cases.
  Stream<Map<String, String>> get onNotificationTap => _tapController.stream;

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Initialize timezone database for scheduled local notifications.
    tzdata.initializeTimeZones();

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

    // 3. Set up flutter_local_notifications (foreground display + tap callback).
    await _setupLocalNotifications();

    // 4. Terminated app: check if app was launched by tapping a notification.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _pendingTap = _extractTapData(initialMessage.data);
    }

    // 5. Background app: notification tapped while app was minimized.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final tapData = _extractTapData(message.data);
      if (tapData != null) _tapController.add(tapData);
    });

    // 6. Save token immediately when auth state becomes logged-in.
    //    Covers: app restart with existing session + fresh login.
    //    Also subscribes/unsubscribes from the lost_reports FCM topic.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _fcm.getToken();
        if (token != null) await _saveToken(token);
        await subscribeToLostReports();
      } else {
        await unsubscribeFromLostReports();
      }
    });

    // 7. Token refresh listener — FCM may rotate the token at any time.
    //    Only saves if a user is currently logged in.
    _fcm.onTokenRefresh.listen((newToken) async {
      if (FirebaseAuth.instance.currentUser != null) {
        await _saveToken(newToken);
      }
    });

    // 8. Foreground message handler — show a local notification banner with
    //    the data payload encoded in the notification payload field so that
    //    a tap on the banner can be routed to the correct screen.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(notification, message.data);
      }
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
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
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

  /// Handles taps on local notification banners (foreground case on Android).
  void _onLocalNotificationTap(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;
      final tapData = _extractTapData(decoded);
      if (tapData != null) _tapController.add(tapData);
    } catch (_) {}
  }

  void _showLocalNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final tapData = _extractTapData(data);
    final payload = tapData != null ? jsonEncode(tapData) : null;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ─── Payload parsing ─────────────────────────────────────────────────────

  /// Extracts {type, reportId} from the FCM data map.
  /// Returns null if any required field is missing, empty, or unsupported.
  Map<String, String>? _extractTapData(Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.trim();
    final reportId = (data['reportId'] as String?)?.trim();
    if (type == null || type.isEmpty || reportId == null || reportId.isEmpty) {
      return null;
    }
    if (type != 'new_lost_report' &&
        type != 'new_lost_message' &&
        type != 'new_found_message' &&
        type != 'new_lost_sighting') {
      return null;
    }
    return {'type': type, 'reportId': reportId};
  }

  // ─── Topic subscriptions ──────────────────────────────────────────────────

  Future<void> subscribeToLostReports() async {
    await _fcm.subscribeToTopic('lost_reports');
  }

  Future<void> unsubscribeFromLostReports() async {
    await _fcm.unsubscribeFromTopic('lost_reports');
  }

  // ─── Health reminder scheduling ───────────────────────────────────────────

  Future<void> scheduleHealthReminder(PetHealthEvent event) async {
    final reminderDate = event.reminderDate;
    if (reminderDate == null) return;
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);
    final id = event.id.hashCode.abs() & 0x7FFFFFFF;

    await _localNotifications.zonedSchedule(
      id,
      event.title,
      event.title,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelHealthReminder(String eventId) async {
    await _localNotifications.cancel(eventId.hashCode.abs() & 0x7FFFFFFF);
  }

  // ─── Token persistence ────────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    await _profileService.saveFcmToken(token);
  }
}
