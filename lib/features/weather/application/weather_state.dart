import '../../../services/weather_service.dart';

enum WeatherStatus { loading, ready, unavailable }

class WeatherState {
  const WeatherState({
    this.status = WeatherStatus.loading,
    this.snapshot,
    this.isRefreshing = false,
    this.error,
  });

  final WeatherStatus status;
  final WeatherSnapshot? snapshot;
  final bool isRefreshing;
  final Object? error;

  bool get hasData => snapshot != null;

  WeatherState copyWith({
    WeatherStatus? status,
    WeatherSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) {
    return WeatherState(
      status: status ?? this.status,
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : error ?? this.error,
    );
  }
}
