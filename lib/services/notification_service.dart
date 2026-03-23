import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String _hasAskedPermissionKey = 'has_asked_notification_permission';

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permission for iOS
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Note: Background message handler is registered in main.dart
    // Do NOT register it here to avoid duplicate background isolate warning

    // Handle foreground messages
    _setupForegroundMessageHandler();

    // Handle notification taps
    _setupNotificationTapHandler();

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_bvn');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Setup foreground message handler (when app is open)
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Show notification even when app is in foreground
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  /// Setup notification tap handler
  void _setupNotificationTapHandler() {
    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state via notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'vocab_battle_channel', // channel id
      'Vocabulary Battle', // channel name
      channelDescription: 'Notifications for Vocabulary Battle game',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_bvn',
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode, // notification id
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final sessionId = data['sessionId'] as String?;

    // TODO: Navigate to appropriate screen based on notification type
    // You can implement navigation logic here based on your requirements

    switch (type) {
      case 'opponentSubmitted':
      case 'battleReady':
      case 'deadlineReminder':
      case 'deadlineMissed':
      case 'battleDayReminder':
      case 'gameComplete':
      default:
        break;
    }

    // Example: If you want to navigate, you can use a GlobalKey<NavigatorState>
    // navigatorKey.currentState?.pushNamed('/home', arguments: sessionId);
  }

  /// Local notification tap handler
  void _onNotificationTapped(NotificationResponse response) {
    // Handle local notification tap
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Check if we've already asked for notification permission
  Future<bool> hasAskedForPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasAskedPermissionKey) ?? false;
  }

  /// Mark that we've asked for notification permission
  Future<void> markPermissionAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasAskedPermissionKey, true);
  }

  /// Check current permission status
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Request permission and initialize if granted
  /// Returns true if permission was granted
  Future<bool> requestPermissionAndInitialize() async {
    // Mark that we've asked
    await markPermissionAsked();

    // Request permission
    await _requestPermission();

    // Check if permission was granted
    final isEnabled = await areNotificationsEnabled();

    if (isEnabled) {
      // Initialize the service if permission granted
      await initialize();
    }

    return isEnabled;
  }
}
