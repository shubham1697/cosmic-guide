import 'dart:convert';

import 'package:cosmic_guide/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Every failure used to collapse into `null`, so an expired session, a
/// throttle and a flat tyre were indistinguishable — to the user and to us.
/// These assert the classification the rest of the app now relies on.
void main() {
  setUp(() {
    ApiService.tokenProvider = () async => 'test-token';
    ApiService.onUnauthorized = null;
    ApiService.lastError.value = null;
    ApiService.clearCache();
  });

  tearDown(() {
    ApiService.client = http.Client();
    ApiService.tokenProvider = null;
    ApiService.onUnauthorized = null;
  });

  void respondWith(
    int status, {
    String body = '{}',
    Map<String, String>? headers,
  }) {
    ApiService.client = MockClient(
      (_) async => http.Response(body, status, headers: headers ?? const {}),
    );
  }

  test('401 signs the user out instead of leaving a dead session', () async {
    var signedOut = false;
    ApiService.onUnauthorized = () async => signedOut = true;
    respondWith(401);

    await expectLater(ApiService.fetchProfile(), throwsA(isA<ApiException>()));
    // The sign-out hook is fired off the request path.
    await Future<void>.delayed(Duration.zero);

    expect(signedOut, isTrue);
    expect(ApiService.lastError.value?.kind, ApiErrorKind.unauthorized);
  });

  test('429 keeps the Retry-After the server sent', () async {
    respondWith(429, headers: {'retry-after': '37'});

    final stories = await ApiService.getStories();

    expect(stories, isEmpty);
    final error = ApiService.lastError.value;
    expect(error?.kind, ApiErrorKind.rateLimited);
    expect(error?.retryAfter, const Duration(seconds: 37));
    expect(error?.message, contains('37s'));
  });

  test('503 is reported as unavailable, not as a sign-in problem', () async {
    var signedOut = false;
    ApiService.onUnauthorized = () async => signedOut = true;
    respondWith(503);

    expect(await ApiService.drawTarotCard(), isNull);
    await Future<void>.delayed(Duration.zero);

    expect(ApiService.lastError.value?.kind, ApiErrorKind.unavailable);
    expect(
      signedOut,
      isFalse,
      reason: 'a server outage must not sign anyone out',
    );
  });

  test('500 is distinguished from an empty result', () async {
    respondWith(500);

    expect(await ApiService.getBirthChart(birthDate: '1990-08-05'), isNull);
    expect(ApiService.lastError.value?.kind, ApiErrorKind.server);
    expect(ApiService.lastError.value?.isRetryable, isTrue);
  });

  test('a transport failure is network, not a bad response', () async {
    ApiService.client = MockClient((_) async => throw const _Offline());

    expect(await ApiService.getTransits(), isEmpty);
    expect(ApiService.lastError.value?.kind, ApiErrorKind.network);
  });

  test('success clears the last error', () async {
    respondWith(429);
    await ApiService.getStories();
    expect(ApiService.lastError.value, isNotNull);

    respondWith(
      200,
      body: json.encode({
        'stories': [
          {
            'title': 'Mercury retrograde',
            'summary': 's',
            'category': 'Planetary',
            'readTime': '4 min',
            'content': 'c',
          },
        ],
      }),
    );
    final stories = await ApiService.getStories();

    expect(stories, hasLength(1));
    expect(ApiService.lastError.value, isNull);
  });

  test(
    'a fallback reading is flagged so the UI can be honest about it',
    () async {
      respondWith(
        200,
        body: json.encode({
          'sign': 'Leo',
          'date': '2026-10-07',
          'general': 'g',
          'love': 'l',
          'career': 'c',
          'health': 'h',
          'overallScore': 75,
          'luckyNumber': '9',
          'luckyColor': 'Purple',
          'mood': 'Intuitive',
          'source': 'fallback',
        }),
      );

      final horoscope = await ApiService.getHoroscope('Leo');

      expect(horoscope, isNotNull);
      expect(horoscope!.isFallback, isTrue);
    },
  );
}

class _Offline implements Exception {
  const _Offline();
}
