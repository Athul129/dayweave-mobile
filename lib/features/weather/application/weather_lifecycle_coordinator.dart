import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/lifecycle/app_lifecycle_service.dart';
import 'weather_controller.dart';

class WeatherLifecycleCoordinator {
  WeatherLifecycleCoordinator({
    required WeatherController controller,
    AppLifecycleService? lifecycleService,
    this.refreshInterval = const Duration(hours: 1),
  }) : _controller = controller {
    _lifecycleService = lifecycleService ??
        AppLifecycleService(onStateChanged: _handleLifecycleState);
  }

  final WeatherController _controller;
  final Duration refreshInterval;
  late final AppLifecycleService _lifecycleService;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    if (_disposed) return;
    _lifecycleService.start();
    _startTimer();
  }

  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _handleLifecycleState(state);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _lifecycleService.dispose();
  }

  void _handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _startTimer();
        _controller.refreshIfNeeded();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopTimer();
    }
  }

  void _startTimer() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(refreshInterval, (_) {
      if (!_disposed) _controller.refreshIfNeeded(force: true);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
