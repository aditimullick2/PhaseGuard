import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Top-level background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[FCM] Background message: ${message.messageId}');
  
  // Data-only payload triggers the local notification directly
  if (message.data['type'] == 'incoming_call') {
    final callerName = message.data['callerName'] ?? 'Someone';
    final callType = message.data['callType'] ?? 'audio';
    final callId = message.data['callId'] ?? '';

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.show(
      callId.hashCode.abs() % 10000,
      'Incoming ${callType == 'video' ? 'Video' : 'Audio'} Call',
      '$callerName is calling...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'incoming_calls', // Must match the channel ID created in initialize()
          'Incoming Calls',
          channelDescription: 'Full-screen notification for incoming audio and video calls',
          icon: '@mipmap/launcher_icon', // Required when local notifications isn't initialized in the isolate
          importance: Importance.max,
          priority: Priority.max,
          showWhen: false,
          fullScreenIntent: true,
          enableVibration: true,
          playSound: true,
          ongoing: true,
          autoCancel: false,
        ),
      ),
    );
  }
}

/// Manages FCM and local notifications.
class NotificationService extends ChangeNotifier {
  static const _channelId = 'incoming_calls';
  static const _channelName = 'Incoming Calls';
  static const _channelDesc =
      'Full-screen notification for incoming audio and video calls';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // ── Initialize ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Request Android notification permission (API 33+)
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    // Request iOS permission
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Initialize local notifications plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    // Create high-importance Android notification channel
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          showBadge: true,
          enableVibration: true,
          playSound: true,
          enableLights: true,
        ),
      );

      // Request exact alarm permission for scheduled notifications (API 31+)
      await androidPlugin.requestExactAlarmsPermission();
    }

    // Token retrieval
    await _refreshToken();

    // Listen for token refresh events
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      notifyListeners();
    });

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle tap on notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Register background handler (idempotent — Dart isolate handles this)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // FCM Token 

  Future<String?> getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      notifyListeners();
      return _fcmToken;
    } catch (e) {
      debugPrint('[NotificationService] Token error: $e');
      return null;
    }
  }

  Future<void> _refreshToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] _refreshToken error: $e');
    }
  }

  // Local notifications

  /// Show a full-screen incoming call notification.
  Future<void> showIncomingCallNotification({
    required String callerName,
    required String callType,
    required String callId,
  }) async {
    await _localNotifications.show(
      callId.hashCode.abs() % 10000,
      'Incoming ${callType == 'video' ? 'Video' : 'Audio'} Call',
      '$callerName is calling...',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: false,
          fullScreenIntent: true, // Lock-screen / heads-up display
          enableVibration: true,
          playSound: true,
          ongoing: true, // Persist until dismissed
          autoCancel: false,
          category: AndroidNotificationCategory.call,
          actions: [
            const AndroidNotificationAction(
              'decline',
              'Decline',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({'callId': callId, 'type': callType}),
    );
  }

  /// Dismiss an ongoing call notification.
  Future<void> dismissCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode.abs() % 10000);
  }

  // FCM: Send call notification to callee 

  /// Send an FCM data message to the callee via the FCM v1 HTTP API.
  ///
  /// ⚠️  For production, this should be done in a Firebase Cloud Function.
  ///     This client-side implementation works for development but requires
  ///     a server key or OAuth token which should NOT be in client code.
  ///
  ///     If you have deployed the Cloud Function (functions/index.js),
  ///     this method is bypassed — the Cloud Function fires on Firestore
  ///     onCreate automatically.
  Future<void> sendCallNotification({
    required String calleeFcmToken,
    required String callerName,
    required String callType,
    required String callId,
  }) async {
    // In production, the Cloud Function handles this automatically.
    // The Firestore listener in CallingService already handles foreground calls.
    // This method is a no-op placeholder — see functions/index.js.
    debugPrint('[NotificationService] FCM delivery delegated to Cloud Function');
  }

  // Handlers 

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[NotificationService] Foreground FCM: ${message.data}');
    // The Firestore listener in CallingService handles the incoming call UI.
    // We only show a local notification if the app is not on the call screen.
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[NotificationService] Notification tapped: ${message.data}');
    // Navigation is handled by the IncomingCallListener in HomeScreen.
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    debugPrint(
        '[NotificationService] Background notification tapped: ${response.payload}');
  }
}
