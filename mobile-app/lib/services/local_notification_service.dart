import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// On-device notifications for the daily horoscope reminder.
///
/// Everything here is local: no server call and no Firebase credentials are
/// needed, and the daily reminder fires in the device's own timezone even when
/// the app is closed.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyId = 1001;
  static const int _testId = 1000;
  static const String _channelId = 'daily_horoscope';
  static const String _channelName = 'Daily Horoscope';
  static const String _channelDesc =
      'Your daily horoscope reminder from CosmicGuide.';

  static bool _inited = false;
  static bool _available = false;

  /// Whether the notifications plugin is usable on this platform/run. False on
  /// web/desktop, or until the app is fully restarted after the plugin was
  /// first added (hot reload/restart don't register new native plugins).
  static bool get isAvailable => _available;

  /// Initialize the plugin and resolve the device timezone. Safe to call more
  /// than once; only the first call does work. Never throws — if the plugin
  /// isn't available the service degrades to no-ops.
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        // Fall back to the package default (UTC) rather than failing to init.
        debugPrint('Local timezone lookup failed: $e');
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _available = true;
    } catch (e) {
      // e.g. MissingPluginException before a full restart picks up the newly
      // added native plugin, or a platform with no implementation (web).
      _available = false;
      debugPrint('Local notifications unavailable: $e');
    }
  }

  /// Prompt for permission to post notifications (Android 13+ and iOS).
  /// Returns true when granted, or when the platform needs no prompt.
  static Future<bool> requestPermissions() async {
    await init();
    if (!_available) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return (await android.requestNotificationsPermission()) ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return (await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )) ??
            false;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions failed: $e');
      return false;
    }
  }

  /// Whether notifications are currently permitted, without prompting.
  static Future<bool> arePermissionsGranted() async {
    await init();
    if (!_available) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return (await android.areNotificationsEnabled()) ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return (await ios.checkPermissions())?.isEnabled ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('arePermissionsGranted failed: $e');
      return false;
    }
  }

  /// Show an immediate test notification.
  static Future<void> showTest() async {
    await init();
    if (!_available) return;
    try {
      await _plugin.show(
        id: _testId,
        title: '🔔 CosmicGuide test',
        body: 'If you can read this, notifications are working!',
        notificationDetails: _details(),
      );
    } catch (e) {
      debugPrint('showTest failed: $e');
    }
  }

  /// (Re)schedule the daily reminder at [hour]:[minute] in local time. Repeats
  /// every day and replaces any existing schedule.
  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    String? zodiacSign,
  }) async {
    await init();
    if (!_available) return;
    try {
      await _plugin.cancel(id: _dailyId);
      final sign = (zodiacSign ?? '').trim();
      final body = sign.isNotEmpty
          ? '$sign, the stars have something to say today. Tap to read. 🔮'
          : 'The stars have something to say today. Tap to read. 🔮';
      await _plugin.zonedSchedule(
        id: _dailyId,
        title: '✨ Your daily horoscope is ready',
        body: body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('scheduleDaily failed: $e');
    }
  }

  /// Cancel the daily reminder.
  static Future<void> cancelDaily() async {
    await init();
    if (!_available) return;
    try {
      await _plugin.cancel(id: _dailyId);
    } catch (e) {
      debugPrint('cancelDaily failed: $e');
    }
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin);
  }

  /// The next occurrence of [hour]:[minute] in local time, today or tomorrow.
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
