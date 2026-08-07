import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_notification_service.dart';

/// Coordinator for the daily horoscope reminder.
///
/// Delivery is on-device via [LocalNotificationService], so the reminder works
/// without any server or Firebase credentials and fires in the user's own
/// timezone. Backend FCM registration is still attempted best-effort so a
/// future server-side campaign can reach opted-in devices; those steps degrade
/// gracefully and never block the local reminder.
class NotificationService {
  static const _enabledKey = 'notifications_enabled';
  static const _tokenKey = 'fcm_token';
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';

  /// Default reminder time (8:00 AM) used until the user picks their own.
  static const int defaultHour = 8;
  static const int defaultMinute = 0;

  /// Reschedule the on-device reminder if the user opted in, then wire FCM
  /// token handling (best-effort). Call once at startup.
  static Future<void> init() async {
    try {
      if (await isEnabled()) {
        final prefs = await SharedPreferences.getInstance();
        await LocalNotificationService.scheduleDaily(
          hour: prefs.getInt(_hourKey) ?? defaultHour,
          minute: prefs.getInt(_minuteKey) ?? defaultMinute,
          zodiacSign: prefs.getString('userSign'),
        );
      }
    } catch (e) {
      debugPrint('daily reminder reschedule skipped: $e');
    }
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
      if (await isEnabled()) {
        final token = await _obtainFcmToken();
        if (token != null) await _registerCurrent(token);
      }
    } catch (e) {
      debugPrint('NotificationService.init FCM skipped: $e');
    }
  }

  /// Whether the daily horoscope reminder is switched on (defaults to off).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Whether the OS currently allows notifications on this device. Does NOT
  /// prompt — drives the status card without side effects.
  static Future<bool> isPushAvailable() async {
    return LocalNotificationService.arePermissionsGranted();
  }

  /// The saved reminder time as (hour, minute), defaulting to 8:00 AM.
  static Future<(int hour, int minute)> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getInt(_hourKey) ?? defaultHour,
      prefs.getInt(_minuteKey) ?? defaultMinute,
    );
  }

  /// Persist a new reminder time and reschedule when the reminder is on.
  static Future<void> setReminderTime({
    required int hour,
    required int minute,
    String? zodiacSign,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    if (await isEnabled()) {
      await LocalNotificationService.scheduleDaily(
        hour: hour,
        minute: minute,
        zodiacSign: zodiacSign ?? prefs.getString('userSign'),
      );
    }
  }

  /// Turn the daily reminder on or off.
  ///
  /// On enable, requests notification permission and schedules the on-device
  /// reminder; returns false only when the OS denied permission. Backend FCM
  /// registration is attempted best-effort (for future server campaigns) and
  /// does not affect the result.
  static Future<bool> setEnabled({
    required bool enabled,
    String? zodiacSign,
    String? tradition,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      final granted = await LocalNotificationService.requestPermissions();
      await LocalNotificationService.scheduleDaily(
        hour: prefs.getInt(_hourKey) ?? defaultHour,
        minute: prefs.getInt(_minuteKey) ?? defaultMinute,
        zodiacSign: zodiacSign ?? prefs.getString('userSign'),
      );
      unawaited(
        _syncFcm(
          enabled: true,
          zodiacSign: zodiacSign,
          tradition: tradition,
          birthDate: birthDate,
          birthTime: birthTime,
          birthPlace: birthPlace,
        ),
      );
      return granted;
    }

    await LocalNotificationService.cancelDaily();
    unawaited(_syncFcm(enabled: false));
    return true;
  }

  /// Best-effort backend registration so a future server-side push can reach
  /// this device. Never throws; failures are logged and ignored.
  static Future<void> _syncFcm({
    required bool enabled,
    String? zodiacSign,
    String? tradition,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    try {
      final token = await _obtainFcmToken();
      if (token == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (enabled) {
        await _registerCurrent(
          token,
          zodiacSign: zodiacSign,
          tradition: tradition,
          birthDate: birthDate,
          birthTime: birthTime,
          birthPlace: birthPlace,
        );
      } else {
        await ApiService.updateNotificationPreferences(
          token: token,
          dailyHoroscopeEnabled: false,
        );
      }
    } catch (e) {
      debugPrint('FCM sync skipped: $e');
    }
  }

  /// Re-register the current device with the latest profile data. Call after
  /// the user edits their sign or birth details. No-op when the reminder is off
  /// or no token is available yet.
  static Future<void> syncRegistration({
    String? zodiacSign,
    String? tradition,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    if (!await isEnabled()) return;
    final token = await _obtainFcmToken();
    if (token == null) return;
    await _registerCurrent(
      token,
      zodiacSign: zodiacSign,
      tradition: tradition,
      birthDate: birthDate,
      birthTime: birthTime,
      birthPlace: birthPlace,
    );
  }

  /// Fire an immediate on-device test notification. Returns false when the OS
  /// has denied notification permission.
  static Future<bool> sendTest() async {
    final granted = await LocalNotificationService.requestPermissions();
    if (!granted) return false;
    await LocalNotificationService.showTest();
    return true;
  }

  /// Register (or refresh) the current token with the backend, filling any
  /// missing profile fields from SharedPreferences. Caches the token locally.
  static Future<bool> _registerCurrent(
    String token, {
    String? zodiacSign,
    String? tradition,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    return ApiService.registerDeviceToken(
      token: token,
      platform: _platform(),
      zodiacSign: zodiacSign ?? prefs.getString('userSign'),
      tradition: tradition ?? prefs.getString('tradition'),
      birthDate: birthDate ?? prefs.getString('birthDate'),
      birthTime: birthTime ?? prefs.getString('birthTime'),
      birthPlace: birthPlace ?? prefs.getString('birthPlace'),
      dailyHoroscopeEnabled: true,
    );
  }

  /// FCM rotated the token — persist it and re-register if the user opted in.
  static Future<void> _onTokenRefresh(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (prefs.getBool(_enabledKey) ?? false) {
      await _registerCurrent(token);
    }
  }

  static String _platform() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// SEAM: obtain the FCM registration token. Returns null when permission is
  /// denied or Firebase isn't available (e.g. desktop), so callers degrade
  /// gracefully.
  static Future<String?> _obtainFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      // iOS requires an APNS token before FCM token is available; simulators never get one.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns;
        for (var i = 0; i < 10 && apns == null; i++) {
          try {
            apns = await messaging.getAPNSToken();
          } catch (_) {}
          if (apns == null) await Future.delayed(const Duration(seconds: 1));
        }
        if (apns == null) return null;
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }
}
