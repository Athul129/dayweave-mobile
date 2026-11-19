import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geolocator_location_service.dart';

class WeatherCoordinates {
  const WeatherCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationFailureKind { permissionDenied, unavailable, timeout, unsupported }

class LocationServiceException implements Exception {
  const LocationServiceException(this.kind, [this.message]);

  final LocationFailureKind kind;
  final String? message;

  @override
  String toString() => message ?? 'Location unavailable: $kind';
}

abstract interface class LocationService {
  Future<WeatherCoordinates> getCurrentLocation();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);
