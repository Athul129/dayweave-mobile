import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dayweave_mobile/services/geolocator_location_service.dart';
import 'package:dayweave_mobile/services/location_service.dart';

class _FakePlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.always;
  LocationPermission requestedPermission = LocationPermission.always;
  Position? position = Position(
    latitude: 12.3,
    longitude: 45.6,
    timestamp: DateTime(2026),
    accuracy: 100,
    altitude: 0,
    altitudeAccuracy: 100,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  Position? lastKnownPosition;
  Object? lastKnownError;
  Completer<Position?>? pendingLastKnown;
  LocationSettings? requestedSettings;
  Object? error;
  int currentCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    // Count invocation before resolving the configured success or failure.
    currentCalls++;
    requestedSettings = locationSettings;
    final failure = error;
    if (failure != null) return Future.error(failure);
    return Future.value(position!);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    if (pendingLastKnown != null) return pendingLastKnown!.future;
    final failure = lastKnownError;
    if (failure != null) return Future.error(failure);
    return Future.value(lastKnownPosition);
  }
}

void main() {
  test('retrieves and caches foreground coordinates', () async {
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(platform: platform);

    final first = await service.getCurrentLocation();
    final second = await service.getCurrentLocation();

    expect(first.latitude, 12.3);
    expect(second.longitude, 45.6);
    expect(platform.currentCalls, 1);
  });

  test('reuses cached coordinates before the fifteen-minute expiry', () async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(
      platform: platform,
      clock: () => now,
    );

    await service.getCurrentLocation();
    now = now.add(const Duration(minutes: 14));
    await service.getCurrentLocation();

    expect(platform.currentCalls, 1);
  });

  test('performs fresh acquisition after cached coordinates expire', () async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(
      platform: platform,
      clock: () => now,
    );

    await service.getCurrentLocation();
    now = now.add(const Duration(minutes: 16));
    await service.getCurrentLocation();

    expect(platform.currentCalls, 2);
  });

  test('does not use cached coordinates when services are disabled', () async {
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(platform: platform);

    await service.getCurrentLocation();
    platform.enabled = false;

    await expectLater(
      service.getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.unavailable,
      )),
    );
    expect(platform.currentCalls, 1);

    platform
      ..enabled = true
      ..position = Position(
        latitude: 13.3,
        longitude: 46.6,
        timestamp: DateTime(2026),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    final refreshed = await service.getCurrentLocation();
    expect(refreshed.latitude, 13.3);
    expect(platform.currentCalls, 2);
  });

  test('invalidates cached coordinates when permission is revoked', () async {
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(platform: platform);

    await service.getCurrentLocation();
    platform.permission = LocationPermission.deniedForever;

    await expectLater(
      service.getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.permissionDenied,
      )),
    );
    expect(platform.currentCalls, 1);

    platform
      ..permission = LocationPermission.always
      ..position = Position(
        latitude: 14.3,
        longitude: 47.6,
        timestamp: DateTime(2026),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    final refreshed = await service.getCurrentLocation();
    expect(refreshed.latitude, 14.3);
    expect(platform.currentCalls, 2);
  });

  test('accepts a recent last-known position without fresh acquisition',
      () async {
    final platform = _FakePlatform()
      ..lastKnownPosition = Position(
        latitude: 12.3,
        longitude: 45.6,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

    final coordinates = await GeolocatorLocationService(
      platform: platform,
    ).getCurrentLocation();

    expect(coordinates.latitude, 12.3);
    expect(platform.currentCalls, 0);
  });

  test('uses fresh location when last-known position is null or stale',
      () async {
    final platform = _FakePlatform()
      ..lastKnownPosition = Position(
        latitude: 12.3,
        longitude: 45.6,
        timestamp: DateTime.now().subtract(const Duration(minutes: 31)),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

    await GeolocatorLocationService(platform: platform).getCurrentLocation();
    expect(platform.currentCalls, 1);

    final nullLastKnown = _FakePlatform();
    await GeolocatorLocationService(
      platform: nullLastKnown,
    ).getCurrentLocation();
    expect(nullLastKnown.currentCalls, 1);
  });

  test('rejects a future-dated last-known position', () async {
    final platform = _FakePlatform()
      ..lastKnownPosition = Position(
        latitude: 12.3,
        longitude: 45.6,
        timestamp: DateTime.now().add(const Duration(minutes: 1)),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

    await GeolocatorLocationService(platform: platform).getCurrentLocation();
    expect(platform.currentCalls, 1);
  });

  test('rejects invalid last-known coordinates and uses fresh location',
      () async {
    final platform = _FakePlatform()
      ..lastKnownPosition = Position(
        latitude: 91,
        longitude: 45.6,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 100,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

    await GeolocatorLocationService(platform: platform).getCurrentLocation();
    expect(platform.currentCalls, 1);
  });

  test('rejects NaN and infinity last-known coordinates', () async {
    for (final invalid in [double.nan, double.infinity]) {
      final platform = _FakePlatform()
        ..lastKnownPosition = Position(
          latitude: invalid,
          longitude: 45.6,
          timestamp: DateTime.now(),
          accuracy: 100,
          altitude: 0,
          altitudeAccuracy: 100,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

      await GeolocatorLocationService(platform: platform).getCurrentLocation();
      expect(platform.currentCalls, 1);
    }
  });

  test('last-known lookup failure falls back to fresh location', () async {
    final platform = _FakePlatform()
      ..lastKnownError = StateError('unavailable');

    final coordinates = await GeolocatorLocationService(
      platform: platform,
    ).getCurrentLocation();

    expect(coordinates.latitude, 12.3);
    expect(platform.currentCalls, 1);
  });

  test('last-known lookup failure preserves fresh timeout mapping', () async {
    final platform = _FakePlatform()
      ..lastKnownError = StateError('unavailable')
      ..error = TimeoutException('timeout');

    await expectLater(
      GeolocatorLocationService(platform: platform).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.timeout,
      )),
    );
    expect(platform.currentCalls, 1);
  });

  test('last-known lookup timeout falls back to fresh location', () async {
    final platform = _FakePlatform()..pendingLastKnown = Completer<Position?>();

    final coordinates = await GeolocatorLocationService(
      platform: platform,
      lastKnownTimeout: Duration.zero,
    ).getCurrentLocation();

    expect(coordinates.latitude, 12.3);
    expect(platform.currentCalls, 1);
  });

  test('uses medium accuracy and a fifteen-second timeout by default',
      () async {
    final platform = _FakePlatform();
    final service = GeolocatorLocationService(platform: platform);

    await service.getCurrentLocation();

    expect(platform.requestedSettings?.accuracy, LocationAccuracy.medium);
    expect(
      platform.requestedSettings?.timeLimit,
      const Duration(seconds: 15),
    );
    expect(service.timeout, const Duration(seconds: 15));
  });

  test('requests permission and maps denial', () async {
    final platform = _FakePlatform()
      ..permission = LocationPermission.denied
      ..requestedPermission = LocationPermission.denied;

    expect(
      GeolocatorLocationService(platform: platform).getCurrentLocation(),
      throwsA(
        isA<LocationServiceException>().having(
          (error) => error.kind,
          'kind',
          LocationFailureKind.permissionDenied,
        ),
      ),
    );
  });

  test('transitions from denied permission to while-in-use permission',
      () async {
    final platform = _FakePlatform()
      ..permission = LocationPermission.denied
      ..requestedPermission = LocationPermission.whileInUse;

    final coordinates = await GeolocatorLocationService(
      platform: platform,
    ).getCurrentLocation();

    expect(coordinates.latitude, 12.3);
    expect(coordinates.longitude, 45.6);
    expect(platform.currentCalls, 1);
  });

  test('maps disabled, permanent denial, and unsupported permission', () async {
    final disabled = _FakePlatform()..enabled = false;
    final permanent = _FakePlatform()
      ..permission = LocationPermission.deniedForever;
    final unsupported = _FakePlatform()
      ..permission = LocationPermission.unableToDetermine;

    expect(
      GeolocatorLocationService(platform: disabled).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.unavailable,
      )),
    );
    expect(
      GeolocatorLocationService(platform: permanent).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.permissionDenied,
      )),
    );
    expect(
      GeolocatorLocationService(platform: unsupported).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.unsupported,
      )),
    );
  });

  test('maps timeout and unavailable errors', () async {
    final timeout = _FakePlatform()..error = TimeoutException('timeout');
    final unavailable = _FakePlatform()..error = StateError('unavailable');

    expect(
      GeolocatorLocationService(platform: timeout).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.timeout,
      )),
    );
    expect(
      GeolocatorLocationService(platform: unavailable).getCurrentLocation(),
      throwsA(isA<LocationServiceException>().having(
        (error) => error.kind,
        'kind',
        LocationFailureKind.unavailable,
      )),
    );
  });
}
