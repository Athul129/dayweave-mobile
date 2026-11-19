import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/features/weather/application/weather_controller.dart';
import 'package:dayweave_mobile/features/weather/presentation/weather_banner.dart';
import 'package:dayweave_mobile/services/location_service.dart';
import 'package:dayweave_mobile/services/weather_service.dart';

class _Location implements LocationService {
  @override
  Future<WeatherCoordinates> getCurrentLocation() async =>
      const WeatherCoordinates(latitude: 1, longitude: 2);
}

class _Weather implements WeatherService {
  _Weather(this.result, {this.error});

  final WeatherSnapshot result;
  final Object? error;

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) async {
    if (error != null) throw error!;
    return result;
  }
}

class _ControlledWeather implements WeatherService {
  _ControlledWeather(this.loader);

  final Future<WeatherSnapshot> Function() loader;
  int calls = 0;

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) {
    calls++;
    return loader();
  }
}

Widget _host(WeatherService service) {
  return ProviderScope(
    overrides: [
      locationServiceProvider.overrideWithValue(_Location()),
      weatherServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(home: Scaffold(body: WeatherBanner())),
  );
}

void main() {
  testWidgets('shows loading and ready weather states', (tester) async {
    final service = _Weather(WeatherSnapshot(
      temperatureCelsius: 24,
      weatherCode: 0,
      isDay: true,
      validAt: DateTime.now().toUtc(),
    ));
    await tester.pumpWidget(_host(service));
    expect(find.text('Getting your weather...'), findsOneWidget);
    await tester.pump();
    expect(find.textContaining('Clear'), findsOneWidget);
    expect(find.textContaining('24°C'), findsOneWidget);
  });

  testWidgets('can align with an already inset parent', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_Location()),
          weatherServiceProvider.overrideWithValue(_Weather(WeatherSnapshot(
            temperatureCelsius: 24,
            weatherCode: 0,
            isDay: true,
            validAt: DateTime.now().toUtc(),
          ))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: WeatherBanner(insetHorizontally: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = tester.getRect(find.byType(Card));
    expect(card.left, 24);
    expect(card.right, 776);
  });

  testWidgets('loading state exposes an accessible progress message',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final pending = Completer<WeatherSnapshot>();
      await tester.pumpWidget(_host(_ControlledWeather(() => pending.future)));
      await tester.pump();

      expect(find.text('Getting your weather...'), findsOneWidget);
      final semanticWidgets =
          tester.widgetList<Semantics>(find.byType(Semantics));
      expect(
        semanticWidgets.any(
          (widget) => widget.properties.label == 'Getting your weather',
        ),
        isTrue,
      );

      pending.complete(WeatherSnapshot(
        temperatureCelsius: 24,
        weatherCode: 0,
        isDay: true,
        validAt: DateTime.now().toUtc(),
      ));
      await tester.pump();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows unavailable state and retries', (tester) async {
    var attempts = 0;
    final service = _RetryWeather(() async {
      attempts++;
      if (attempts == 1) throw StateError('offline');
      return WeatherSnapshot(
        temperatureCelsius: 20,
        weatherCode: 2,
        isDay: true,
        validAt: DateTime.now().toUtc(),
      );
    });
    await tester.pumpWidget(_host(service));
    await tester.pump();
    expect(find.text('Weather is unavailable right now.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(find.textContaining('Partly cloudy'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('ready weather has no refresh error when error is absent',
      (tester) async {
    await tester.pumpWidget(_host(_Weather(WeatherSnapshot(
      temperatureCelsius: 24,
      weatherCode: 0,
      isDay: true,
      validAt: DateTime.now().toUtc(),
    ))));
    await tester.pump();

    expect(find.text("Couldn't refresh weather"), findsNothing);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    expect(find.textContaining('Clear'), findsOneWidget);
  });

  testWidgets('maps location failures to actionable messages', (tester) async {
    final cases = {
      LocationFailureKind.permissionDenied:
          'Allow location access to see local weather.',
      LocationFailureKind.unavailable:
          'Turn on location services to see local weather.',
      LocationFailureKind.timeout: "We couldn't determine your location.",
      LocationFailureKind.unsupported:
          'Location is unavailable on this device.',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(_host(_Weather(
        WeatherSnapshot(
          temperatureCelsius: 20,
          weatherCode: 0,
          isDay: true,
          validAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        ),
        error: LocationServiceException(entry.key),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('maps weather failures to actionable messages', (tester) async {
    final cases = {
      WeatherFailureKind.network:
          "Weather couldn't be loaded. Check your connection.",
      WeatherFailureKind.timeout: 'The weather request timed out. Try again.',
      WeatherFailureKind.http:
          'The weather service is temporarily unavailable.',
      WeatherFailureKind.invalidResponse:
          'Weather data is temporarily unavailable.',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(_host(_Weather(
        WeatherSnapshot(
          temperatureCelsius: 20,
          weatherCode: 0,
          isDay: true,
          validAt: DateTime.now().toUtc(),
        ),
        error: WeatherServiceException(entry.key, 'test failure'),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('distinguishes stale weather from fresh weather', (tester) async {
    await tester.pumpWidget(_host(_Weather(WeatherSnapshot(
      temperatureCelsius: 24,
      weatherCode: 0,
      isDay: true,
      validAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      fetchedAt: DateTime.now().toUtc(),
    ))));
    await tester.pump();

    expect(find.text('Weather data may be out of date'), findsOneWidget);
    expect(find.textContaining('Clear'), findsOneWidget);
  });

  testWidgets('refresh error preserves weather and supports retry',
      (tester) async {
    final first = Completer<WeatherSnapshot>();
    var attempt = 0;
    final service = _ControlledWeather(() {
      attempt++;
      if (attempt == 1)
        return Future.value(WeatherSnapshot(
          temperatureCelsius: 24,
          weatherCode: 0,
          isDay: true,
          validAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        ));
      if (attempt == 2) return Future.error(StateError('offline'));
      return first.future;
    });
    await tester.pumpWidget(_host(service));
    await tester.pump();
    expect(find.textContaining('Clear'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WeatherBanner)),
    );
    await container.read(weatherProvider.notifier).load();
    await tester.pump();
    expect(find.textContaining('Clear'), findsOneWidget);
    expect(find.text("Couldn't refresh weather"), findsOneWidget);
    expect(find.text('Weather data may be out of date'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(service.calls, 3);
    expect(find.text("Couldn't refresh weather"), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Retry'))
          .onPressed,
      isNull,
    );

    first.complete(WeatherSnapshot(
      temperatureCelsius: 25,
      weatherCode: 2,
      isDay: true,
      validAt: DateTime.now().toUtc(),
    ));
    await tester.pump();
    expect(find.text("Couldn't refresh weather"), findsNothing);
    expect(find.textContaining('Partly cloudy'), findsOneWidget);
  });

  testWidgets('failed retry preserves weather and re-enables Retry',
      (tester) async {
    var attempt = 0;
    final service = _ControlledWeather(() async {
      attempt++;
      if (attempt == 1) {
        return WeatherSnapshot(
          temperatureCelsius: 24,
          weatherCode: 0,
          isDay: true,
          validAt: DateTime.now().toUtc(),
        );
      }
      throw StateError('offline $attempt');
    });
    await tester.pumpWidget(_host(service));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WeatherBanner)),
    );
    await container.read(weatherProvider.notifier).load();
    await tester.pump();

    expect(find.textContaining('Clear'), findsOneWidget);
    expect(find.text("Couldn't refresh weather"), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Retry'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(find.textContaining('Clear'), findsOneWidget);
    expect(find.text("Couldn't refresh weather"), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Retry'))
          .onPressed,
      isNotNull,
    );
  });
}

class _RetryWeather implements WeatherService {
  _RetryWeather(this.loader);
  final Future<WeatherSnapshot> Function() loader;

  @override
  Future<WeatherSnapshot> fetchCurrent(WeatherCoordinates coordinates) =>
      loader();
}
