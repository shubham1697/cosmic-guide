import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// The kinds of readings recorded in the history timeline.
class ReadingType {
  static const horoscope = 'horoscope';
  static const tarot = 'tarot';
  static const fortune = 'fortune';
}

/// A single recorded reading event — a tarot draw, a fortune, or a daily
/// horoscope view — with the moment it happened.
class ReadingEntry {
  final String type;
  final String title;
  final String subtitle;
  final DateTime date;

  const ReadingEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'date': date.toIso8601String(),
  };

  factory ReadingEntry.fromJson(Map<String, dynamic> json) => ReadingEntry(
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Aggregate stats derived from the history and shown on the profile.
class ReadingStats {
  final int totalReadings;
  final int streakDays;
  final int fortuneCount;

  const ReadingStats({
    required this.totalReadings,
    required this.streakDays,
    required this.fortuneCount,
  });

  const ReadingStats.empty()
    : totalReadings = 0,
      streakDays = 0,
      fortuneCount = 0;
}

/// Persists the user's reading history (tarot, fortune, horoscope) locally and
/// derives real profile stats — total readings, current day streak, and
/// fortune count — from it. Backed by SharedPreferences, so no account is
/// required.
class HistoryService {
  static const _key = 'reading_history';
  static const _maxEntries = 200;

  /// Records a reading event, keeping only the most recent [_maxEntries].
  static Future<void> record({
    required String type,
    required String title,
    String subtitle = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(
      json.encode(
        ReadingEntry(
          type: type,
          title: title,
          subtitle: subtitle,
          date: DateTime.now(),
        ).toJson(),
      ),
    );
    if (raw.length > _maxEntries) {
      raw.removeRange(0, raw.length - _maxEntries);
    }
    await prefs.setStringList(_key, raw);
  }

  /// Records the daily horoscope view at most once per calendar day, so the
  /// streak reflects days engaged without inflating the readings count each
  /// time Home reloads.
  static Future<void> recordDailyHoroscope({
    required String sign,
    required String system,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final today = _dayKey(DateTime.now());
    final alreadyToday = raw.any((e) {
      final entry = ReadingEntry.fromJson(
        json.decode(e) as Map<String, dynamic>,
      );
      return entry.type == ReadingType.horoscope &&
          _dayKey(entry.date) == today;
    });
    if (alreadyToday) return;
    await record(
      type: ReadingType.horoscope,
      title: '$sign daily horoscope',
      subtitle: system == 'vedic' ? 'Vedic · Janma Rashi' : 'Western',
    );
  }

  /// All recorded entries, newest first.
  static Future<List<ReadingEntry>> entries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final list = raw
        .map(
          (e) => ReadingEntry.fromJson(json.decode(e) as Map<String, dynamic>),
        )
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Derived profile stats: total readings, current day streak, fortune count.
  static Future<ReadingStats> stats() async {
    final list = await entries();
    if (list.isEmpty) return const ReadingStats.empty();
    final fortunes = list.where((e) => e.type == ReadingType.fortune).length;
    final days = list.map((e) => _dayKey(e.date)).toSet();
    return ReadingStats(
      totalReadings: list.length,
      streakDays: _computeStreak(days),
      fortuneCount: fortunes,
    );
  }

  /// Clears all reading history.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Current consecutive-day streak ending today — or yesterday, so a streak is
  /// not considered broken until a full day has been missed.
  static int _computeStreak(Set<String> days) {
    var cursor = DateTime.now();
    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(_dayKey(cursor))) return 0;
    }
    var streak = 0;
    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
