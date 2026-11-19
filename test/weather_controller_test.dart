import 'dart:async';

import 'package:dayweave_mobile/features/weather/application/weather_controller.dart';
import 'package:dayweave_mobile/features/weather/application/weather_state.dart';
import 'package:dayweave_mobile/services/location_service.dart';
import 'package:dayweave_mobile/services/weather_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.result);

  WeatherCoordinates result;
  Object? error;
  int calls = 0;
  Completer<WeatherCoordinates>? pending;

  @override
  Future<WeatherCoordinates> getCurrentLocation() async {
    calls++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return result;
  }
}

class _FakeWeatherService implements WeatherService {
  _FakeWeatherService(this.result);

  WeatherSnapshot result;
  Object? error;
  int calls = 0;
  WeatherCoordinates? requestedCoordinates;
  Completer<WeatherSnapshot>? pending;

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) {
    calls++;
    requestedCoordinates = coordinates;
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    return Future.value(result);
  }
}

ProviderContainer _container(
  _FakeLocationService location,
  _FakeWeatherService weather,
) {
  return ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(location),
      weatherServiceProvider.overrideWithValue(weather),
    ],
  );
}

void main() {
  const coordinates = WeatherCoordinates(latitude: 12.9, longitude: 77.6);
  final snapshot = WeatherSnapshot(
    temperatureCelsius: 24.5,
    weatherCode: 2,
    isDay: true,
    validAt: DateTime.now().toUtc(),
  );

  test('starts in the initial loading state', () {
    final container = _container(
      _FakeLocationService(coordinates),
      _FakeWeatherService(snapshot),
    );
    addTearDown(container.dispose);

    expect(container.read(weatherProvider).status, WeatherStatus.loading);
    expect(container.read(weatherProvider).snapshot, isNull);
  });

  test('retrieves weather through injected location and weather services',
      () async {
    final location = _FakeLocationService(coordinates);
    final weather = _FakeWeatherService(snapshot);
    final container = _container(location, weather);
    addTearDown(container.dispose);

    await container.read(weatherProvider.notifier).load();

    final state = container.read(weatherProvider);
    expect(state.status, WeatherStatus.ready);
    expect(state.snapshot, snapshot);
    expect(weather.requestedCoordinates, coordinates);
    expect(location.calls, 1);
    expect(weather.calls, 1);
  });

  test('fresh weather skips a redundant refresh within the cooldown', () async {
    final location = _FakeLocationService(coordinates);
    final weather = _FakeWeatherService(snapshot);
    final container = _container(location, weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    await controller.refreshIfNeeded(
      now: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

    expect(location.calls, 1);
    expect(weather.calls, 1);
  });

  test('stale weather refreshes after the resume cooldown', () async {
    final location = _FakeLocationService(coordinates);
    final weather = _FakeWeatherService(WeatherSnapshot(
      temperatureCelsius: 24.5,
      weatherCode: 2,
      isDay: true,
      validAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      fetchedAt: DateTime.now().toUtc(),
    ));
    final container = _container(location, weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    await controller.refreshIfNeeded(
      now: DateTime.now().toUtc().add(const Duration(minutes: 20)),
    );

    expect(location.calls, 2);
    expect(weather.calls, 2);
  });

  test('location recovery bypasses the resume cooldown', () async {
    final location = _FakeLocationService(coordinates);
    final container = _container(location, _FakeWeatherService(snapshot));
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    location.error = const LocationServiceException(
      LocationFailureKind.permissionDenied,
    );
    await controller.load();
    location.error = null;
    await controller.refreshIfNeeded();

    expect(location.calls, 3);
    expect(container.read(weatherProvider).status, WeatherStatus.ready);
    expect(container.read(weatherProvider).snapshot, snapshot);
  });

  for (final kind in LocationFailureKind.values) {
    test('location ${kind.name} produces an unavailable state', () async {
      final location = _FakeLocationService(coordinates)
        ..error = LocationServiceException(kind);
      final container = _container(location, _FakeWeatherService(snapshot));
      addTearDown(container.dispose);

      await container.read(weatherProvider.notifier).load();

      final state = container.read(weatherProvider);
      expect(state.status, WeatherStatus.unavailable);
      expect(state.snapshot, isNull);
      expect(state.error, isA<LocationServiceException>());
    });
  }

  test('weather service failure produces an unavailable state', () async {
    final weather = _FakeWeatherService(snapshot)
      ..error = StateError('offline');
    final container = _container(_FakeLocationService(coordinates), weather);
    addTearDown(container.dispose);

    await container.read(weatherProvider.notifier).load();

    expect(container.read(weatherProvider).status, WeatherStatus.unavailable);
    expect(container.read(weatherProvider).error, isA<StateError>());
  });

  test('an unusable response does not replace a valid previous snapshot',
      () async {
    final weather = _FakeWeatherService(snapshot);
    final container = _container(_FakeLocationService(coordinates), weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    weather.result = WeatherSnapshot(
      temperatureCelsius: 10,
      weatherCode: 3,
      isDay: true,
      validAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
      fetchedAt: DateTime.now().toUtc(),
    );
    await controller.load();

    final state = container.read(weatherProvider);
    expect(state.status, WeatherStatus.ready);
    expect(state.snapshot, snapshot);
    expect(state.error, isA<WeatherServiceException>());
  });

  test('refresh failure preserves previous weather and exposes the error',
      () async {
    final weather = _FakeWeatherService(snapshot);
    final container = _container(_FakeLocationService(coordinates), weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    weather.error = StateError('offline');
    await controller.load();

    final state = container.read(weatherProvider);
    expect(state.status, WeatherStatus.ready);
    expect(state.snapshot, snapshot);
    expect(state.error, isA<StateError>());
    expect(state.isRefreshing, isFalse);
  });

  test('permission failure clears previously loaded weather', () async {
    final location = _FakeLocationService(coordinates);
    final container = _container(location, _FakeWeatherService(snapshot));
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    location.error = const LocationServiceException(
      LocationFailureKind.permissionDenied,
    );
    await controller.load();

    final state = container.read(weatherProvider);
    expect(state.status, WeatherStatus.unavailable);
    expect(state.snapshot, isNull);
    expect(state.error, isA<LocationServiceException>());
    expect(state.isRefreshing, isFalse);
  });

  test('disabled location services clear previously loaded weather', () async {
    final location = _FakeLocationService(coordinates);
    final container = _container(location, _FakeWeatherService(snapshot));
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    location.error = const LocationServiceException(
      LocationFailureKind.unavailable,
    );
    await controller.load();

    final state = container.read(weatherProvider);
    expect(state.status, WeatherStatus.unavailable);
    expect(state.snapshot, isNull);
    expect(state.error, isA<LocationServiceException>());
    expect(state.isRefreshing, isFalse);
  });

  test('retry after failure can recover', () async {
    final weather = _FakeWeatherService(snapshot)
      ..error = StateError('offline');
    final container = _container(_FakeLocationService(coordinates), weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    await controller.load();
    weather.error = null;
    weather.result = WeatherSnapshot(
      temperatureCelsius: 28,
      weatherCode: 0,
      isDay: true,
      validAt: DateTime.now().toUtc(),
    );
    await controller.retry();

    expect(container.read(weatherProvider).status, WeatherStatus.ready);
    expect(container.read(weatherProvider).snapshot?.temperatureCelsius, 28);
    expect(container.read(weatherProvider).error, isNull);
  });

  test('concurrent refresh requests share one in-flight request', () async {
    final weather = _FakeWeatherService(snapshot)
      ..pending = Completer<WeatherSnapshot>();
    final location = _FakeLocationService(coordinates)
      ..pending = Completer<WeatherCoordinates>();
    final container = _container(location, weather);
    addTearDown(container.dispose);
    final controller = container.read(weatherProvider.notifier);

    final first = controller.load();
    final second = controller.load();
    expect(identical(first, second), isTrue);
    expect(location.calls, 1);
    expect(weather.calls, 0);

    var firstCompleted = false;
    var secondCompleted = false;
    first.whenComplete(() => firstCompleted = true);
    second.whenComplete(() => secondCompleted = true);

    location.pending!.complete(coordinates);
    await Future<void>.value();
    expect(weather.calls, 1);
    expect(firstCompleted, isFalse);
    expect(secondCompleted, isFalse);

    weather.pending!.complete(snapshot);
    await Future.wait([first, second]);

    expect(firstCompleted, isTrue);
    expect(secondCompleted, isTrue);
    expect(container.read(weatherProvider).snapshot, snapshot);

    await controller.load();
    expect(location.calls, 2);
    expect(weather.calls, 2);
  });
}
