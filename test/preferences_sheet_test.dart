import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dayweave_mobile/features/preferences/application/preferences_controller.dart';
import 'package:dayweave_mobile/features/preferences/application/preferences_storage.dart';
import 'package:dayweave_mobile/features/preferences/presentation/preferences_sheet.dart';

void main() {
  testWidgets('selecting a preset saves the selected duration', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);

    await tester.tap(find.text('45 minutes'));
    await tester.pumpAndSettle();

    expect(storage.value, 45);
  });

  testWidgets('custom input saves valid values and rejects invalid values',
      (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);

    await tester.tap(find.text('Custom'));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, '35');
    await tester.pumpAndSettle();
    expect(storage.value, 35);

    await tester.enterText(field, '31');
    await tester.pump();
    expect(
        find.text('Choose a duration in 5-minute increments.'), findsOneWidget);
    expect(storage.value, 35);
  });

  testWidgets('switching custom to a preset keeps the preset selected',
      (tester) async {
    final storage = _FakeStorage(value: 35);
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);

    await tester.tap(find.text('45 minutes'));
    await tester.pumpAndSettle();

    expect(storage.value, 45);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('switching preset to Custom does not save until valid input',
      (tester) async {
    final storage = _FakeStorage(value: 30);
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);

    await tester.tap(find.text('Custom'));
    await tester.pump();
    expect(storage.value, 30);

    final field = find.byType(TextField);
    await tester.enterText(field, '');
    await tester.pump();
    expect(storage.value, 30);
    expect(
        find.text('Enter a duration from 1 to 1,440 minutes.'), findsOneWidget);
  });

  testWidgets('invalid custom values show validation without persistence',
      (tester) async {
    final storage = _FakeStorage(value: 30);
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);
    await tester.tap(find.text('Custom'));
    await tester.pump();
    final field = find.byType(TextField);

    for (final value in ['abc', '0', '1445', '31']) {
      await tester.enterText(field, value);
      await tester.pump();
      expect(storage.value, 30);
    }
  });

  testWidgets('persisted value is displayed when the sheet is reopened',
      (tester) async {
    final storage = _FakeStorage(value: 45);
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);
    expect(find.text('45 minutes'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PreferencesSheet))).pop();
    await tester.pumpAndSettle();
    await _openSheet(tester);
    expect(find.text('45 minutes'), findsOneWidget);
  });

  testWidgets('save failure exposes retry and retry can succeed',
      (tester) async {
    final storage = _FakeStorage()..failNextWrite = true;
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);

    await tester.tap(find.text('45 minutes'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save this preference. Please try again.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(storage.value, 45);
    expect(find.text('Could not save this preference. Please try again.'),
        findsNothing);
  });

  testWidgets('shows loading while preferences are being read', (tester) async {
    final storage = _FakeStorage(readGate: Completer<void>());
    await tester.pumpWidget(_app(storage));
    await tester.tap(find.text('Open preferences'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    storage.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('load failure is displayed and retry loads the stored value',
      (tester) async {
    final storage = _FakeStorage()..readError = StateError('offline');
    await tester.pumpWidget(_app(storage));
    await _openSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text('Could not load saved preferences. Using the default.'),
        findsOneWidget);

    storage.readError = null;
    storage.value = 60;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('60 minutes'), findsOneWidget);
    expect(find.text('Could not load saved preferences. Using the default.'),
        findsNothing);
  });
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open preferences'));
  await tester.pumpAndSettle();
}

Widget _app(_FakeStorage storage) => ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(storage),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPreferencesSheet(context),
                child: const Text('Open preferences'),
              ),
            ),
          ),
        ),
      ),
    );

class _FakeStorage implements PreferencesStorage {
  _FakeStorage({this.value, this.readGate});

  int? value;
  Completer<void>? readGate;
  Object? readError;
  bool failNextWrite = false;

  @override
  Future<int?> readDefaultTaskMinutes() async {
    final gate = readGate;
    if (gate != null) await gate.future;
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> writeDefaultTaskMinutes(int value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const PreferencesStorageWriteException();
    }
    this.value = value;
  }
}
