import 'package:flutter/widgets.dart';

class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService({
    required this.onStateChanged,
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance;

  final void Function(AppLifecycleState state) onStateChanged;
  final WidgetsBinding _binding;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _binding.addObserver(this);
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    _binding.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_started) onStateChanged(state);
  }
}
