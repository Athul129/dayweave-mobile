import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_state.dart';
import 'preferences_storage.dart';

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => SharedPreferencesStorage(),
);

final preferencesProvider =
    NotifierProvider<PreferencesController, PreferencesState>(
  PreferencesController.new,
);

class PreferencesController extends Notifier<PreferencesState> {
  late final PreferencesStorage _storage;
  Future<void>? _loadRequest;
  Future<void> _operationTail = Future<void>.value();
  bool _initialized = false;

  @override
  PreferencesState build() {
    _storage = ref.watch(preferencesStorageProvider);
    Future<void>.microtask(load);
    return const PreferencesState();
  }

  Future<void> load() {
    if (_initialized) return Future<void>.value();
    final existing = _loadRequest;
    if (existing != null) return existing;
    final request = _load();
    _loadRequest = request;
    request.whenComplete(() {
      _initialized = state.errorKind != PreferencesErrorKind.load;
      if (identical(_loadRequest, request)) _loadRequest = null;
    });
    return request;
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null, errorKind: null);
    try {
      final value = await _storage.readDefaultTaskMinutes();
      state = state.copyWith(
        defaultTaskMinutes: normalizeDefaultTaskMinutes(value),
        isLoading: false,
        error: null,
        errorKind: null,
      );
    } catch (error) {
      state = state.copyWith(
        defaultTaskMinutes: defaultTaskMinutes,
        isLoading: false,
        error: error,
        errorKind: PreferencesErrorKind.load,
      );
    }
  }

  Future<void> save(int value) async {
    _validate(value);
    await load();
    if (value == state.defaultTaskMinutes &&
        state.errorKind != PreferencesErrorKind.save) return;
    await _enqueue(() async {
      state = state.copyWith(
          defaultTaskMinutes: value,
          isSaving: true,
          error: null,
          errorKind: null);
      try {
        await _storage.writeDefaultTaskMinutes(value);
        state = state.copyWith(isSaving: false, error: null, errorKind: null);
      } catch (error) {
        state = state.copyWith(
          isSaving: false,
          error: error,
          errorKind: PreferencesErrorKind.save,
        );
      }
    });
  }

  Future<void> reset() => save(defaultTaskMinutes);

  Future<void> _enqueue(Future<void> Function() operation) {
    final request = _operationTail.then((_) => operation());
    _operationTail = request.then<void>((_) {}, onError: (_, __) {});
    return request;
  }

  void _validate(int value) {
    if (!isValidDefaultTaskMinutes(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'Use a whole number from 1 to 1,440 in five-minute increments.',
      );
    }
  }
}
