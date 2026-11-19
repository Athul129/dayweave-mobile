import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/location_service.dart';
import '../../../services/weather_service.dart';
import 'weather_state.dart';

final weatherProvider =
    NotifierProvider<WeatherController, WeatherState>(WeatherController.new);

class WeatherController extends Notifier<WeatherState> {
  static const resumeCooldown = Duration(minutes: 15);

  Future<void>? _requestInFlight;
  DateTime? _lastRefreshAttemptAt;
  bool _locationRecoveryNeeded = false;

  late LocationService _locationService;
  late WeatherService _weatherService;

  @override
  WeatherState build() {
    _locationService = ref.watch(locationServiceProvider);
    _weatherService = ref.watch(weatherServiceProvider);
    return const WeatherState();
  }

  Future<void> load() {
    final existing = _requestInFlight;
    if (existing != null) return existing;

    late final Future<void> sharedRequest;
    sharedRequest = _performLoad().whenComplete(() {
      if (identical(_requestInFlight, sharedRequest)) {
        _requestInFlight = null;
      }
    });
    _requestInFlight = sharedRequest;
    return sharedRequest;
  }

  Future<void> refreshIfNeeded({DateTime? now, bool force = false}) {
    final existing = _requestInFlight;
    if (existing != null) return existing;

    final snapshot = state.snapshot;
    if (snapshot == null) return load();

    final currentTime = (now ?? DateTime.now()).toUtc();
    final freshness = snapshot.freshnessAt(currentTime);
    final lastAttempt = _lastRefreshAttemptAt;
    final cooldownActive = lastAttempt != null &&
        currentTime.difference(lastAttempt) < resumeCooldown;
    if (_locationRecoveryNeeded) return load();
    if (cooldownActive) return Future<void>.value();
    if (freshness == WeatherFreshness.fresh && !force) {
      return Future<void>.value();
    }
    return load();
  }

  Future<void> _performLoad() async {
    _lastRefreshAttemptAt = DateTime.now().toUtc();
    final previous = state.snapshot;
    final previousError = state.error;
    _logState('loading/refreshing', hasPreviousSnapshot: previous != null);
    state = WeatherState(
      status: previous == null ? WeatherStatus.loading : WeatherStatus.ready,
      snapshot: previous,
      isRefreshing: previous != null,
      error: previous == null ? null : previousError,
    );

    try {
      final coordinates = await _locationService.getCurrentLocation();
      final snapshot = await _weatherService.fetchCurrent(coordinates);
      if (snapshot.freshnessAt(DateTime.now()) == WeatherFreshness.unusable) {
        throw const WeatherServiceException(
          WeatherFailureKind.invalidResponse,
          'Weather service returned unusable historical data.',
        );
      }
      state = WeatherState(
        status: WeatherStatus.ready,
        snapshot: snapshot,
      );
      _locationRecoveryNeeded = false;
      _logState('ready', hasPreviousSnapshot: true);
    } catch (error) {
      final locationFailure = error is LocationServiceException;
      if (locationFailure) _locationRecoveryNeeded = true;
      state = WeatherState(
        status: locationFailure || previous == null
            ? WeatherStatus.unavailable
            : WeatherStatus.ready,
        snapshot: locationFailure ? null : previous,
        error: error,
      );
      _logState(
        previous == null ? 'unavailable' : 'ready with refresh error',
        hasPreviousSnapshot: previous != null,
      );
    } finally {
      if (state.isRefreshing) {
        state = state.copyWith(isRefreshing: false);
        _logState('refresh completed',
            hasPreviousSnapshot: state.snapshot != null);
      }
    }
  }

  Future<void> retry() => load();

  void _logState(String stateName, {required bool hasPreviousSnapshot}) {
    if (kDebugMode) {
      debugPrint(
        '[Weather][Controller] state=$stateName '
        'hasSnapshot=${state.snapshot != null} '
        'hasPreviousSnapshot=$hasPreviousSnapshot '
        'isRefreshing=${state.isRefreshing} '
        'hasError=${state.error != null}',
      );
    }
  }
}
