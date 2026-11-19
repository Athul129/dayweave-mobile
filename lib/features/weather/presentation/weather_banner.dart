import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../../services/location_service.dart';
import '../../../services/weather_service.dart';
import '../application/weather_controller.dart';
import '../application/weather_state.dart';

class WeatherBanner extends ConsumerStatefulWidget {
  const WeatherBanner({super.key, this.insetHorizontally = true});

  final bool insetHorizontally;

  @override
  ConsumerState<WeatherBanner> createState() => _WeatherBannerState();
}

class _WeatherBannerState extends ConsumerState<WeatherBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(weatherProvider.notifier).refreshIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weatherProvider);
    final theme = Theme.of(context);
    final content = switch (state.status) {
      WeatherStatus.loading => const _WeatherMessage(
          icon: Icons.cloud_outlined,
          message: 'Getting your weather...',
          semanticsLabel: 'Getting your weather',
          loading: true,
        ),
      WeatherStatus.unavailable => _WeatherMessage(
          icon: _weatherErrorIcon(state.error),
          message: _weatherErrorMessage(state.error),
          semanticsLabel: _weatherErrorMessage(state.error),
          action: TextButton(
            onPressed: state.isRefreshing
                ? null
                : () => ref.read(weatherProvider.notifier).retry(),
            child: const Text('Retry'),
          ),
        ),
      WeatherStatus.ready when state.snapshot != null => _WeatherReady(
          snapshot: state.snapshot!,
          refreshing: state.isRefreshing,
          refreshError: state.error != null,
          stale: state.snapshot!.freshnessAt(DateTime.now()) ==
              WeatherFreshness.stale,
          onRetry: () => ref.read(weatherProvider.notifier).retry(),
        ),
      WeatherStatus.ready => const _WeatherMessage(
          icon: Icons.cloud_outlined,
          message: 'Weather is unavailable right now.',
        ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        DayweaveSpacing.sm,
        0,
        0,
      ).copyWith(
        left: widget.insetHorizontally ? DayweaveSpacing.lg : 0,
        right: widget.insetHorizontally ? DayweaveSpacing.lg : 0,
      ),
      child: Card(
        color: DayweaveColors.bluePaper,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DayweaveSpacing.md,
            vertical: DayweaveSpacing.sm,
          ),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _WeatherReady extends StatelessWidget {
  const _WeatherReady({
    required this.snapshot,
    required this.refreshing,
    required this.refreshError,
    required this.stale,
    required this.onRetry,
  });

  final WeatherSnapshot snapshot;
  final bool refreshing;
  final bool refreshError;
  final bool stale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_weatherIcon(snapshot.weatherCode, snapshot.isDay), size: 28),
            const SizedBox(width: DayweaveSpacing.sm),
            Expanded(
              child: Text(
                '${_weatherCondition(snapshot.weatherCode)}  \u2022  ${snapshot.temperatureCelsius.round()}\u00B0C',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel:
                    '${_weatherCondition(snapshot.weatherCode)}, ${snapshot.temperatureCelsius.round()} degrees Celsius',
              ),
            ),
            if (refreshing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (refreshError)
          Row(
            children: [
              const Expanded(child: Text("Couldn't refresh weather")),
              TextButton(
                onPressed: refreshing ? null : onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        if (stale)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Weather data may be out of date'),
          ),
      ],
    );
  }
}

class _WeatherMessage extends StatelessWidget {
  const _WeatherMessage({
    required this.icon,
    required this.message,
    this.loading = false,
    this.action,
    this.semanticsLabel,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final Widget? action;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: loading,
      label: semanticsLabel ?? message,
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: DayweaveSpacing.sm),
          Expanded(child: Text(message)),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

String _weatherErrorMessage(Object? error) {
  if (error is LocationServiceException) {
    return switch (error.kind) {
      LocationFailureKind.permissionDenied =>
        'Allow location access to see local weather.',
      LocationFailureKind.unavailable =>
        'Turn on location services to see local weather.',
      LocationFailureKind.timeout => "We couldn't determine your location.",
      LocationFailureKind.unsupported =>
        'Location is unavailable on this device.',
    };
  }
  if (error is WeatherServiceException) {
    return switch (error.kind) {
      WeatherFailureKind.network =>
        "Weather couldn't be loaded. Check your connection.",
      WeatherFailureKind.timeout => 'The weather request timed out. Try again.',
      WeatherFailureKind.http =>
        'The weather service is temporarily unavailable.',
      WeatherFailureKind.invalidResponse =>
        'Weather data is temporarily unavailable.',
    };
  }
  return 'Weather is unavailable right now.';
}

IconData _weatherErrorIcon(Object? error) {
  if (error is LocationServiceException) return Icons.location_off_outlined;
  if (error is WeatherServiceException) return Icons.cloud_off_outlined;
  return Icons.cloud_off_outlined;
}

IconData _weatherIcon(int code, bool isDay) {
  if (code == 0)
    return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
  if (code <= 3) return Icons.cloud_outlined;
  if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
    return Icons.grain;
  }
  if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
    return Icons.ac_unit;
  }
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_outlined;
}

String _weatherCondition(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code >= 51 && code <= 67 || code >= 80 && code <= 82) return 'Rain';
  if (code >= 71 && code <= 86) return 'Snow';
  if (code >= 95) return 'Storm';
  return 'Cloudy';
}
