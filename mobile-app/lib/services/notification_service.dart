import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Client-side coordinator for push notifications.
///
/// It persists the user's reminder preference locally and keeps the backend's
/// device registration in sync. The actual push token is produced by
/// [_obtainFcmToken] — the single seam that `firebase_messaging` plugs into
/// once a Firebase project is configured (see the setup notes in the repo).
/// Until then it returns null and every network step degrades gracefully, so
/// the app keeps building and running without Firebase.
class NotificationService {
  static const _enabledKey = 'notifications_enabled';
  static const _tokenKey = 'fcm_token';

  /// Whether the daily horoscope reminder is switched on (defaults to off).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// True once a real push token has been obtained — i.e. Firebase is wired up
  /// and the OS granted permission. Drives the "setup pending" UI state.
  static Future<bool> isPushAvailable() async {
    return (await _obtainFcmToken()) != null;
  }

  /// Turn the daily reminder on or off and reconcile with the backend.
  ///
  /// The local preference is always saved. Returns true when the backend was
  /// successfully updated; false when there's no token yet (Firebase not set
  /// up), in which case the choice is remembered and applied once push is
  /// enabled.
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

    final token = await _obtainFcmToken();
    if (token == null) return false;
    await prefs.setString(_tokenKey, token);

    if (enabled) {
      return ApiService.registerDeviceToken(
        token: token,
        platform: _platform(),
        zodiacSign: zodiacSign,
        tradition: tradition,
        birthDate: birthDate,
        birthTime: birthTime,
        birthPlace: birthPlace,
        dailyHoroscopeEnabled: true,
      );
    }
    return ApiService.updateNotificationPreferences(
      token: token,
      dailyHoroscopeEnabled: false,
    );
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await ApiService.registerDeviceToken(
      token: token,
      platform: _platform(),
      zodiacSign: zodiacSign,
      tradition: tradition,
      birthDate: birthDate,
      birthTime: birthTime,
      birthPlace: birthPlace,
      dailyHoroscopeEnabled: true,
    );
  }

  /// Send a backend test push to this device. Returns false when push isn't
  /// configured yet (no token) or the server has no FCM credentials.
  static Future<bool> sendTest() async {
    final token = await _obtainFcmToken();
    if (token == null) return false;
    return ApiService.sendTestPush(token: token);
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
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }
}
