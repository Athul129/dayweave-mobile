import 'package:flutter/widgets.dart';

class AppLifecycleService with WidgetsBindingObserver {
  void start() => WidgetsBinding.instance.addObserver(this);
  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
