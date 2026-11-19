import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.isDay,
    this.validAt,
    this.fetchedAt,
    this.interval,
    this.timezone,
  });

  final double temperatureCelsius;
  final int weatherCode;
  final bool isDay;
  final DateTime? validAt;
  final DateTime? fetchedAt;
  final Duration? interval;
  final String? timezone;

  WeatherFreshness freshnessAt(DateTime now) {
    final timestamp = validAt;
    if (timestamp == null) return WeatherFreshness.unusable;
    final age = now.toUtc().difference(timestamp.toUtc());
    if (age.isNegative && age.abs() > const Duration(minutes: 5)) {
      return WeatherFreshness.unusable;
    }
    if (age > const Duration(hours: 24)) return WeatherFreshness.unusable;
    if (age > const Duration(minutes: 90)) return WeatherFreshness.stale;
    return WeatherFreshness.fresh;
  }
}

enum WeatherFreshness { fresh, stale, unusable }

abstract interface class WeatherService {
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates);
}

enum WeatherFailureKind { http, network, timeout, invalidResponse }

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.kind, this.message, {this.statusCode});

  final WeatherFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({
    required http.Client client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client;

  final http.Client _client;
  final Duration timeout;

  Uri _uri(WeatherCoordinates coordinates) => Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': coordinates.latitude.toString(),
          'longitude': coordinates.longitude.toString(),
          'current': 'temperature_2m,weather_code,is_day',
          'temperature_unit': 'celsius',
          'timezone': 'UTC',
        },
      );

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) async {
    try {
      final uri = _uri(coordinates);
      _log('Open-Meteo request started.');
      final response = await _client.get(uri).timeout(timeout);
      final fetchedAt = DateTime.now().toUtc();
      _log('Open-Meteo request completed with HTTP ${response.statusCode}.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WeatherServiceException(
          WeatherFailureKind.http,
          'Weather service returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const WeatherServiceException(
          WeatherFailureKind.invalidResponse,
          'Weather service returned an invalid response.',
        );
      }
      final current = decoded['current'];
      if (current is! Map<String, dynamic> ||
          current['temperature_2m'] is! num ||
          current['weather_code'] is! num ||
          current['is_day'] is! num ||
          current['time'] is! String) {
        _log(
            'Weather parsing failure: required current fields are missing or malformed.');
        throw const WeatherServiceException(
          WeatherFailureKind.invalidResponse,
          'Weather service response is missing required fields.',
        );
      }

      final validAt = _parseApiTimestamp(current['time'] as String);
      final now = DateTime.now().toUtc();
      if (validAt == null ||
          validAt.difference(now) > const Duration(minutes: 5)) {
        _log('Weather parsing failure: current timestamp is invalid.');
        throw const WeatherServiceException(
          WeatherFailureKind.invalidResponse,
          'Weather service response has an invalid current timestamp.',
        );
      }

      final intervalValue = current['interval'];
      final interval = intervalValue is num && intervalValue >= 0
          ? Duration(seconds: intervalValue.round())
          : null;
      final timezone = decoded['timezone'];
      final snapshot = WeatherSnapshot(
        temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num).toInt() == 1,
        validAt: validAt,
        fetchedAt: fetchedAt,
        interval: interval,
        timezone: timezone is String ? timezone : null,
      );
      _log('Weather response parsed successfully.');
      return snapshot;
    } on WeatherServiceException catch (error) {
      _log('Weather service failure: ${error.kind}; $error');
      rethrow;
    } on TimeoutException {
      _log('Weather request failure: timeout.');
      throw const WeatherServiceException(
        WeatherFailureKind.timeout,
        'Weather request timed out.',
      );
    } on FormatException {
      _log('Weather parsing failure: invalid JSON.');
      throw const WeatherServiceException(
        WeatherFailureKind.invalidResponse,
        'Weather service returned invalid JSON.',
      );
    } catch (error) {
      _log('Weather request failure: $error');
      throw WeatherServiceException(
        WeatherFailureKind.network,
        'Unable to reach the weather service: $error',
      );
    }
  }

  DateTime? _parseApiTimestamp(String value) {
    final hasTimezone =
        value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
    return DateTime.tryParse(hasTimezone ? value : '${value}Z')?.toUtc();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Weather][Open-Meteo] $message');
  }
}

final weatherServiceProvider = Provider<WeatherService>(
  (ref) {
    final client = http.Client();
    ref.onDispose(client.close);
    return OpenMeteoWeatherService(client: client);
  },
);
