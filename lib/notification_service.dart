import 'package:flutter/foundation.dart';
// Conditional import for web notifications fallback
import 'web_notifications_stub.dart'
    if (dart.library.html) 'web_notifications_web.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;
  // On some platforms (web) the plugin is not supported. Expose this so UI
  // can disable scheduling when appropriate.
  bool isSupported = true;

  Future<void> init() async {
    if (_initialized) return;

    // Detect unsupported platforms early. The plugin does not support web.
    if (kIsWeb) {
      isSupported = false;
      _initialized = true;
      return;
    }

    // initialize timezone data
    tz.initializeTimeZones();
    try {
      final String localTz = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      if (kDebugMode) print('Could not get the local timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // create plugin instance lazily (avoid construction on web where the
    // plugin's platform interface may not be initialized)
    _plugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin!.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      // You can handle notification tapped behavior here if needed.
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (!isSupported) return;
    await _plugin
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestPermission();

    await _plugin
        ?.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails();

    return const NotificationDetails(android: android, iOS: ios);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await init();
    if (!isSupported) {
      // On web: show a fallback in-page notification if possible
      if (kDebugMode)
        print(
          'Notifications not supported on this platform; trying web fallback',
        );
      // showWebNotification is a conditional import: web implementation will
      // show a browser Notification, stub is a no-op on other platforms.
      await showWebNotification(title, body);
      return;
    }

    // convert to timezone-aware TZDateTime
    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin!.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      _notificationDetails(),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$id',
    );
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await init();
    if (!isSupported) return <PendingNotificationRequest>[];

    final List<PendingNotificationRequest>? list = await _plugin!
        .pendingNotificationRequests();
    return list ?? <PendingNotificationRequest>[];
  }

  Future<void> cancel(int id) async {
    await _plugin?.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin?.cancelAll();
  }
}
