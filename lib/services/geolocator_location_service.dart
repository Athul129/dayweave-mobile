import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    GeolocatorPlatform? platform,
    this.timeout = const Duration(seconds: 15),
    this.lastKnownTimeout = const Duration(seconds: 3),
    DateTime Function()? clock,
  })  : _platform = platform ?? GeolocatorPlatform.instance,
        _clock = clock ?? DateTime.now;

  static const cacheLifetime = Duration(minutes: 15);
  final GeolocatorPlatform _platform;
  final Duration timeout;
  final Duration lastKnownTimeout;
  final DateTime Function() _clock;
  WeatherCoordinates? _cachedCoordinates;
  DateTime? _cachedCoordinatesAt;

  @override
  Future<WeatherCoordinates> getCurrentLocation() async {
    try {
      _log('Checking location service availability.');
      final serviceEnabled = await _platform.isLocationServiceEnabled();
      _log('Location service enabled: $serviceEnabled.');
      if (!serviceEnabled) {
        _cachedCoordinates = null;
        _cachedCoordinatesAt = null;
        throw const LocationServiceException(
          LocationFailureKind.unavailable,
          'Location services are disabled.',
        );
      }

      var permission = await _platform.checkPermission();
      _log('Location permission status: ${permission.name}.');
      if (permission == LocationPermission.denied) {
        _log('Requesting foreground location permission.');
        permission = await _platform.requestPermission();
        _log('Location permission result: ${permission.name}.');
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _cachedCoordinates = null;
        _cachedCoordinatesAt = null;
        throw const LocationServiceException(
          LocationFailureKind.permissionDenied,
          'Location permission was denied.',
        );
      }
      if (permission == LocationPermission.unableToDetermine) {
        _cachedCoordinates = null;
        _cachedCoordinatesAt = null;
        throw const LocationServiceException(
          LocationFailureKind.unsupported,
          'Location permission cannot be determined on this platform.',
        );
      }

      final cached = _cachedCoordinates;
      final cachedAt = _cachedCoordinatesAt;
      final cacheAge = cachedAt == null ? null : _clock().difference(cachedAt);
      if (cached != null &&
          cacheAge != null &&
          cacheAge >= Duration.zero &&
          cacheAge <= cacheLifetime) {
        _log('Using cached location coordinates.');
        return cached;
      }
      _cachedCoordinates = null;
      _cachedCoordinatesAt = null;

      Position? lastKnown;
      final lastKnownStopwatch = Stopwatch()..start();
      _log(
        'Starting last-known location lookup '
        '(timeout: $lastKnownTimeout).',
      );
      try {
        lastKnown =
            await _platform.getLastKnownPosition().timeout(lastKnownTimeout);
        lastKnownStopwatch.stop();
        _log(
          'Last-known location lookup completed in '
          '${lastKnownStopwatch.elapsedMilliseconds}ms; '
          '${lastKnown == null ? 'returned null' : 'returned a position'}.',
        );
      } on TimeoutException {
        lastKnownStopwatch.stop();
        _log(
          'Last-known location lookup timed out after '
          '${lastKnownStopwatch.elapsedMilliseconds}ms; '
          'requesting fresh location.',
        );
      } catch (error) {
        lastKnownStopwatch.stop();
        _log(
          'Last-known location lookup failed after '
          '${lastKnownStopwatch.elapsedMilliseconds}ms; '
          '${_safeErrorDetails(error)}; requesting fresh location.',
        );
      }
      final lastKnownCoordinates = _acceptableCoordinates(lastKnown);
      final lastKnownAge =
          lastKnown == null ? null : _clock().difference(lastKnown.timestamp);
      if (lastKnownCoordinates != null &&
          lastKnownAge != null &&
          lastKnownAge >= Duration.zero &&
          lastKnownAge <= const Duration(minutes: 30)) {
        _cachedCoordinates = lastKnownCoordinates;
        _cachedCoordinatesAt = _clock();
        _log('Using a recent last-known location.');
        return lastKnownCoordinates;
      }
      _log(
          'No acceptable recent last-known location; requesting fresh location.');

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      );
      _log(
        'Starting fresh location acquisition '
        '(timeout: $timeout; native LocationSettings.timeLimit: $timeout).',
      );
      final currentLocationStopwatch = Stopwatch()..start();
      Position position;
      try {
        position = await _platform
            .getCurrentPosition(locationSettings: locationSettings)
            .timeout(timeout);
        currentLocationStopwatch.stop();
        _log(
          'Fresh location acquisition completed in '
          '${currentLocationStopwatch.elapsedMilliseconds}ms; '
          'returned a position.',
        );
      } on TimeoutException {
        currentLocationStopwatch.stop();
        _log(
          'Fresh location acquisition timed out after '
          '${currentLocationStopwatch.elapsedMilliseconds}ms.',
        );
        rethrow;
      } catch (error) {
        currentLocationStopwatch.stop();
        _log(
          'Fresh location acquisition failed after '
          '${currentLocationStopwatch.elapsedMilliseconds}ms; '
          '${_safeErrorDetails(error)}.',
        );
        rethrow;
      }
      final coordinates = _acceptableCoordinates(position);
      if (coordinates == null) {
        throw const LocationServiceException(
          LocationFailureKind.unavailable,
          'The device returned an invalid location.',
        );
      }

      _cachedCoordinates = coordinates;
      _cachedCoordinatesAt = _clock();
      _log('Location acquisition completed with valid coordinates.');
      return coordinates;
    } on LocationServiceException catch (error) {
      _log('Location failure: ${error.kind}; $error');
      rethrow;
    } on TimeoutException {
      _log('Location failure: timeout.');
      throw const LocationServiceException(
        LocationFailureKind.timeout,
        'Location request timed out.',
      );
    } on UnsupportedError {
      _log('Location failure: unsupported platform.');
      throw const LocationServiceException(
        LocationFailureKind.unsupported,
        'Location is not supported on this platform.',
      );
    } on PermissionDefinitionsNotFoundException {
      _log('Location failure: permission definitions unavailable.');
      throw const LocationServiceException(
        LocationFailureKind.unsupported,
        'Location permission is not configured on this platform.',
      );
    } on PermissionDeniedException {
      _log('Location failure: permission denied by platform.');
      throw const LocationServiceException(
        LocationFailureKind.permissionDenied,
        'Location permission was denied.',
      );
    } on MissingPluginException {
      _log('Location failure: missing platform plugin.');
      throw const LocationServiceException(
        LocationFailureKind.unsupported,
        'Location is not supported on this platform.',
      );
    } catch (error) {
      _log('Location failure: $error');
      throw LocationServiceException(
        LocationFailureKind.unavailable,
        'Unable to determine the device location: $error',
      );
    }
  }

  WeatherCoordinates? _acceptableCoordinates(Position? position) {
    if (position == null ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      return null;
    }
    return WeatherCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Weather][Location] $message');
  }

  String _safeErrorDetails(Object error) =>
      'exceptionType=${error.runtimeType}; details=${error.toString()}';
}
