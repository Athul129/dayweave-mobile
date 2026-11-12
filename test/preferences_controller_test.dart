import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dayweave_mobile/features/preferences/application/preferences_controller.dart';
import 'package:dayweave_mobile/features/preferences/application/preferences_state.dart';
import 'package:dayweave_mobile/features/preferences/application/preferences_storage.dart';

class _FakePreferencesStorage implements PreferencesStorage {
  int? value;
  Object? readError;
  Object? writeError;
  bool failNextWrite = false;
  int reads = 0;
  int writes = 0;
  final writeGate = <Completer<void>>[];
  final writeStarted = <int>[];

  @override
  Future<int?> readDefaultTaskMinutes() async {
    reads++;
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> writeDefaultTaskMinutes(int value) async {
    writes++;
    writeStarted.add(value);
    if (writeGate.isNotEmpty) await writeGate.removeAt(0).future;
    if (failNextWrite) {
      failNextWrite = false;
      throw const PreferencesStorageWriteException();
    }
    if (writeError != null) throw writeError!;
    this.value = value;
  }
}

ProviderContainer _container(_FakePreferencesStorage storage) =>
    ProviderContainer(overrides: [
      preferencesStorageProvider.overrideWithValue(storage),
    ]);

Future<PreferencesController> _controller(ProviderContainer container) async {
  final controller = container.read(preferencesProvider.notifier);
  await controller.load();
  return controller;
}

void main() {
  test('empty storage uses the default', () async {
    final storage = _FakePreferencesStorage();
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    expect(controller.state.defaultTaskMinutes, defaultTaskMinutes);
  });

  test('loads valid preset and custom values', () async {
    for (final value in [15, 30, 45, 60, 35]) {
      final storage = _FakePreferencesStorage()..value = value;
      final container = _container(storage);
      addTearDown(container.dispose);
      final controller = await _controller(container);
      expect(controller.state.defaultTaskMinutes, value);
    }
  });

  test('normalizes invalid stored values to 30', () async {
    for (final value in [0, -5, 1441, 31, '30', null]) {
      final storage = _FakePreferencesStorage()
        ..value = value is int ? value : null;
      final container = _container(storage);
      addTearDown(container.dispose);
      final controller = await _controller(container);
      expect(controller.state.defaultTaskMinutes, defaultTaskMinutes);
    }
  });

  test('saves valid values and avoids unnecessary writes', () async {
    final storage = _FakePreferencesStorage()..value = 30;
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    await controller.save(30);
    await controller.save(35);
    expect(storage.writes, 1);
    expect(controller.state.defaultTaskMinutes, 35);
  });

  test('rejects invalid values', () async {
    final container = _container(_FakePreferencesStorage());
    addTearDown(container.dispose);
    final controller = await _controller(container);
    for (final value in [0, 1441, 31]) {
      await expectLater(controller.save(value), throwsArgumentError);
    }
  });

  test('reset returns to 30', () async {
    final storage = _FakePreferencesStorage()..value = 45;
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    await controller.reset();
    expect(controller.state.defaultTaskMinutes, defaultTaskMinutes);
    expect(storage.value, defaultTaskMinutes);
  });

  test('read failure keeps the safe default and exposes an error', () async {
    final storage = _FakePreferencesStorage()..readError = StateError('read');
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    expect(controller.state.defaultTaskMinutes, defaultTaskMinutes);
    expect(controller.state.errorKind, PreferencesErrorKind.load);
  });

  test('write failure retains the value and exposes an error', () async {
    final storage = _FakePreferencesStorage()..writeError = StateError('write');
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    await controller.save(45);
    expect(controller.state.defaultTaskMinutes, 45);
    expect(controller.state.errorKind, PreferencesErrorKind.save);
  });

  test('a false storage result is exposed as a save failure', () async {
    final storage = _FakePreferencesStorage()..failNextWrite = true;
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    await controller.save(45);
    expect(controller.state.defaultTaskMinutes, 45);
    expect(controller.state.error, isA<PreferencesStorageWriteException>());
    expect(controller.state.errorKind, PreferencesErrorKind.save);
  });

  test('a failed write can retry the same value successfully', () async {
    final storage = _FakePreferencesStorage()..failNextWrite = true;
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    await controller.save(45);
    await controller.save(45);
    expect(storage.value, 45);
    expect(controller.state.error, isNull);
  });

  test('reset recovers after a failed write', () async {
    final storage = _FakePreferencesStorage()..value = 45;
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    storage.failNextWrite = true;
    await controller.save(60);
    await controller.reset();
    expect(storage.value, defaultTaskMinutes);
    expect(controller.state.defaultTaskMinutes, defaultTaskMinutes);
    expect(controller.state.error, isNull);
  });

  test('concurrent saves are serialized in invocation order', () async {
    final storage = _FakePreferencesStorage();
    final firstWrite = Completer<void>();
    storage.writeGate.add(firstWrite);
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = await _controller(container);
    final first = controller.save(45);
    final second = controller.save(60);
    await Future<void>.delayed(Duration.zero);
    expect(storage.writeStarted, [45]);
    firstWrite.complete();
    await Future.wait([first, second]);
    expect(storage.writeStarted, [45, 60]);
    expect(storage.value, 60);
    expect(controller.state.defaultTaskMinutes, 60);
  });

  test('initialization is shared and save waits for the read', () async {
    final storage = _FakePreferencesStorage();
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = container.read(preferencesProvider.notifier);
    await Future.wait([controller.load(), controller.load()]);
    expect(storage.reads, 1);
    await controller.save(45);
    expect(storage.value, 45);
  });
}
