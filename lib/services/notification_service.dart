import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class CriticalAlertSystem {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // --- CONFIGURATION ---
  static const String _channelIdCritical = 'ghost_critical_v1';
  static const String _channelNameCritical = '🚨 SOS ALERTS';
  static const String _channelDescCritical = 'Overrides Do Not Disturb for emergencies';

  static const String _channelIdStatus = 'ghost_status_v1';
  static const String _channelNameStatus = 'Background Monitoring';

  // --- INITIALIZATION ---
  static Future<void> initializeSystem({
    required Function(String?) onNotificationTap,
    required Function(String) onActionReceived
  }) async {
    
    // 1. Android Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. iOS Setup (Crucial for permissions)
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings
    );

    // 3. Initialize & Handle Taps
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Handle Action Buttons (e.g., User clicked "I'M SAFE")
        if (response.actionId != null) {
          onActionReceived(response.actionId!);
        } else {
          onNotificationTap(response.payload);
        }
      },
    );

    // 4. Create Advanced Channels (Android 8.0+)
    await _createNotificationChannels();
  }

  static Future<void> _createNotificationChannels() async {
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (platform != null) {
      // CHANNEL 1: THE SCREAM (Critical)
      // This channel is designed to wake the dead (and the user)
      await platform.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelIdCritical,
          _channelNameCritical,
          description: _channelDescCritical,
          importance: Importance.max, // MAX importance pops up on screen
          playSound: true,
          enableVibration: true,
          // Custom vibration pattern: SOS (...)
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 1000]), 
        ),
      );

      // CHANNEL 2: THE WHISPER (Status)
      await platform.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelIdStatus,
          _channelNameStatus,
          importance: Importance.low, // No sound, just visuals
          playSound: false,
        ),
      );
    }
  }

  // --- ACTIONS ---

  /// Triggers a Full-Screen, High-Priority Alarm
  static Future<void> dispatchCriticalAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Permission Check (Android 13+)
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelIdCritical,
      _channelNameCritical,
      channelDescription: _channelDescCritical,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true, // Wakes up the screen even if locked!
      category: AndroidNotificationCategory.alarm,
      ticker: 'CRITICAL ALERT',
      visibility: NotificationVisibility.public,
      
      // ACTION BUTTONS (The "Wow" Factor)
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_safe', 
          '✅ I AM SAFE', 
          showsUserInterface: true,
          cancelNotification: true
        ),
        const AndroidNotificationAction(
          'call_sos', 
          '📞 CALL 911', 
          showsUserInterface: true
        ),
      ],
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true, 
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical // iOS Critical Alert
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Updates the permanent notification for background services
  static Future<void> updateServiceStatus(String statusText) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelIdStatus,
      _channelNameStatus,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // User cannot swipe this away easily
      autoCancel: false,
      showWhen: false,
    );

    await _notifications.show(
      999, // Fixed ID for the service notification
      'Ghost Protocol Active',
      statusText,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
