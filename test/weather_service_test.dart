import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dayweave_mobile/services/location_service.dart';
import 'package:dayweave_mobile/services/weather_service.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  Uri? requestedUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requestedUri = request.url;
    return handler(request);
  }
}

http.StreamedResponse _response(String body, {int statusCode = 200}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  const coordinates = WeatherCoordinates(latitude: 12.3, longitude: 45.6);

  test('parses Open-Meteo current weather and sends expected parameters',
      () async {
    final validTime = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 15))
        .toIso8601String();
    final client = _FakeClient((_) async => _response('''
      {"timezone":"Asia/Kolkata","current":{"temperature_2m":27.5,"weather_code":3,"is_day":1,"time":"$validTime","interval":900}}
    '''));
    final service = OpenMeteoWeatherService(client: client);

    final snapshot = await service.fetchCurrent(coordinates);

    expect(snapshot.temperatureCelsius, 27.5);
    expect(snapshot.weatherCode, 3);
    expect(snapshot.isDay, isTrue);
    expect(client.requestedUri!.queryParameters, {
      'latitude': '12.3',
      'longitude': '45.6',
      'current': 'temperature_2m,weather_code,is_day',
      'temperature_unit': 'celsius',
      'timezone': 'UTC',
    });
    expect(snapshot.validAt, DateTime.parse(validTime).toUtc());
    expect(snapshot.fetchedAt, isNotNull);
    expect(snapshot.interval, const Duration(minutes: 15));
    expect(snapshot.timezone, 'Asia/Kolkata');
  });

  test('rejects missing fields, malformed JSON, and HTTP errors', () async {
    final missing = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response('{"current":{}}')),
    );
    final malformed = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response('not json')),
    );
    final failed = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response('error', statusCode: 503)),
    );

    expect(
      missing.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>().having(
        (error) => error.kind,
        'kind',
        WeatherFailureKind.invalidResponse,
      )),
    );
    expect(
      malformed.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>().having(
        (error) => error.kind,
        'kind',
        WeatherFailureKind.invalidResponse,
      )),
    );
    expect(
      failed.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>()
          .having((error) => error.kind, 'kind', WeatherFailureKind.http)
          .having((error) => error.statusCode, 'statusCode', 503)),
    );
  });

  test('rejects a missing or malformed current timestamp', () async {
    final missing = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response(
            '{"current":{"temperature_2m":20,"weather_code":0,"is_day":1}}',
          )),
    );
    final malformed = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response(
            '{"current":{"temperature_2m":20,"weather_code":0,"is_day":1,"time":"invalid"}}',
          )),
    );

    for (final service in [missing, malformed]) {
      await expectLater(
        service.fetchCurrent(coordinates),
        throwsA(isA<WeatherServiceException>().having(
          (error) => error.kind,
          'kind',
          WeatherFailureKind.invalidResponse,
        )),
      );
    }
  });

  test('interprets timezone-less API timestamps as UTC', () async {
    final client = _FakeClient((_) async => _response('''
      {"timezone":"UTC","current":{"temperature_2m":20,"weather_code":0,"is_day":1,"time":"2026-01-01T12:00"}}
    '''));

    final snapshot =
        await OpenMeteoWeatherService(client: client).fetchCurrent(coordinates);

    expect(snapshot.validAt, DateTime.utc(2026, 1, 1, 12));
    expect(client.requestedUri!.queryParameters['timezone'], 'UTC');
  });

  test('rejects a current timestamp too far in the future', () async {
    final service = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response('''
        {"current":{"temperature_2m":20,"weather_code":0,"is_day":1,"time":"2099-01-01T00:00"}}
      ''')),
    );

    await expectLater(
      service.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>().having(
        (error) => error.kind,
        'kind',
        WeatherFailureKind.invalidResponse,
      )),
    );
  });

  test('optional interval and timezone metadata may be absent', () async {
    final service = OpenMeteoWeatherService(
      client: _FakeClient((_) async => _response('''
        {"current":{"temperature_2m":20,"weather_code":0,"is_day":1,"time":"2026-01-01T00:00Z"}}
      ''')),
    );

    final snapshot = await service.fetchCurrent(coordinates);
    expect(snapshot.interval, isNull);
    expect(snapshot.timezone, isNull);
  });

  test('freshness uses validAt rather than fetchedAt', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final boundary = WeatherSnapshot(
      temperatureCelsius: 20,
      weatherCode: 0,
      isDay: true,
      validAt: now.subtract(const Duration(minutes: 90)),
      fetchedAt: now,
    );
    final stale = WeatherSnapshot(
      temperatureCelsius: 20,
      weatherCode: 0,
      isDay: true,
      validAt: now.subtract(const Duration(minutes: 91)),
      fetchedAt: now,
    );
    final unusable = WeatherSnapshot(
      temperatureCelsius: 20,
      weatherCode: 0,
      isDay: true,
      validAt: now.subtract(const Duration(hours: 25)),
      fetchedAt: now,
    );

    expect(boundary.freshnessAt(now), WeatherFreshness.fresh);
    expect(stale.freshnessAt(now), WeatherFreshness.stale);
    expect(unusable.freshnessAt(now), WeatherFreshness.unusable);
    final missingTimestamp = WeatherSnapshot(
      temperatureCelsius: 20,
      weatherCode: 0,
      isDay: true,
      fetchedAt: now,
    );
    expect(missingTimestamp.freshnessAt(now), WeatherFreshness.unusable);
  });

  test('maps network failures and timeouts', () async {
    final network = OpenMeteoWeatherService(
      client: _FakeClient((_) async => throw const SocketException('offline')),
    );
    final pending = OpenMeteoWeatherService(
      client: _FakeClient((_) => Completer<http.StreamedResponse>().future),
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      network.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>().having(
        (error) => error.kind,
        'kind',
        WeatherFailureKind.network,
      )),
    );
    expect(
      pending.fetchCurrent(coordinates),
      throwsA(isA<WeatherServiceException>().having(
        (error) => error.kind,
        'kind',
        WeatherFailureKind.timeout,
      )),
    );
  });
}
