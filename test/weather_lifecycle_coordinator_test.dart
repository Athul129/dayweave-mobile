import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/lifecycle/app_lifecycle_service.dart';
import 'package:dayweave_mobile/features/weather/application/weather_controller.dart';
import 'package:dayweave_mobile/features/weather/application/weather_lifecycle_coordinator.dart';
import 'package:dayweave_mobile/services/location_service.dart';
import 'package:dayweave_mobile/services/weather_service.dart';

class _Location implements LocationService {
  _Location(this.coordinates);

  final WeatherCoordinates coordinates;
  Object? error;
  int calls = 0;
  Completer<WeatherCoordinates>? pending;

  @override
  Future<WeatherCoordinates> getCurrentLocation() {
    calls++;
    final failure = error;
    if (failure != null) return Future.error(failure);
    return pending?.future ?? Future.value(coordinates);
  }
}

class _Weather implements WeatherService {
  _Weather(this.snapshot);

  final WeatherSnapshot snapshot;
  int calls = 0;
  Completer<WeatherSnapshot>? pending;

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) {
    calls++;
    return pending?.future ?? Future.value(snapshot);
  }
}

ProviderContainer _container(_Location location, _Weather weather) {
  return ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(location),
      weatherServiceProvider.overrideWithValue(weather),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const coordinates = WeatherCoordinates(latitude: 12, longitude: 77);
  final snapshot = WeatherSnapshot(
    temperatureCelsius: 24,
    weatherCode: 0,
    isDay: true,
    validAt: DateTime.now().toUtc(),
  );

  test('background lifecycle states stop periodic refresh', () {
    fakeAsync((async) {
      final location = _Location(coordinates);
      final weather = _Weather(snapshot);
      final container = _container(location, weather);
      final coordinator = WeatherLifecycleCoordinator(
        controller: container.read(weatherProvider.notifier),
        refreshInterval: const Duration(hours: 1),
      )..start();

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        coordinator.handleLifecycleState(state);
        async.elapse(const Duration(hours: 1));
        async.flushMicrotasks();
        expect(location.calls, 0);
      }

      coordinator.dispose();
      container.dispose();
    });
  });

  test('resume restarts foreground work and follows recovery policy', () {
    fakeAsync((async) {
      final location = _Location(coordinates)
        ..error =
            const LocationServiceException(LocationFailureKind.unavailable);
      final weather = _Weather(snapshot);
      final container = _container(location, weather);
      final coordinator = WeatherLifecycleCoordinator(
        controller: container.read(weatherProvider.notifier),
        refreshInterval: const Duration(hours: 1),
      )..start();

      coordinator.handleLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(location.calls, 1);

      location.error = null;
      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(location.calls, 2);

      coordinator.dispose();
      container.dispose();
    });
  });

  test('disposal stops timer and lifecycle callbacks', () {
    fakeAsync((async) {
      final location = _Location(coordinates);
      final weather = _Weather(snapshot);
      final container = _container(location, weather);
      final controller = container.read(weatherProvider.notifier);
      late WeatherLifecycleCoordinator coordinator;
      late void Function(AppLifecycleState) onState;
      final lifecycle = AppLifecycleService(
        onStateChanged: (state) => onState(state),
      );
      coordinator = WeatherLifecycleCoordinator(
        controller: controller,
        lifecycleService: lifecycle,
        refreshInterval: const Duration(hours: 1),
      )..start();
      onState = coordinator.handleLifecycleState;

      coordinator.dispose();
      async.elapse(const Duration(hours: 2));
      async.flushMicrotasks();
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();

      expect(location.calls, 0);
      container.dispose();
    });
  });

  test('starting twice does not create duplicate active timers', () {
    fakeAsync((async) {
      final location = _Location(coordinates);
      final weather = _Weather(snapshot);
      final container = _container(location, weather);
      final coordinator = WeatherLifecycleCoordinator(
        controller: container.read(weatherProvider.notifier),
        refreshInterval: const Duration(minutes: 1),
      );

      coordinator
        ..start()
        ..start();
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();

      expect(location.calls, 1);
      coordinator.dispose();
      container.dispose();
    });
  });

  test('resume and periodic tick share an in-flight request', () {
    fakeAsync((async) {
      final location = _Location(coordinates)
        ..pending = Completer<WeatherCoordinates>();
      final weather = _Weather(snapshot);
      final container = _container(location, weather);
      final coordinator = WeatherLifecycleCoordinator(
        controller: container.read(weatherProvider.notifier),
        refreshInterval: const Duration(hours: 1),
      )..start();

      coordinator.handleLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(location.calls, 1);

      location.pending!.complete(coordinates);
      async.flushMicrotasks();
      async.flushMicrotasks();
      expect(weather.calls, 1);

      coordinator.dispose();
      container.dispose();
    });
  });
}
