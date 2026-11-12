import 'package:shared_preferences/shared_preferences.dart';

const defaultTaskMinutesKey = 'dayweave.defaultTaskMinutes';

class PreferencesStorageWriteException implements Exception {
  const PreferencesStorageWriteException();

  @override
  String toString() => 'Preferences could not be saved.';
}

abstract interface class PreferencesStorage {
  Future<int?> readDefaultTaskMinutes();

  Future<void> writeDefaultTaskMinutes(int value);
}

class SharedPreferencesStorage implements PreferencesStorage {
  SharedPreferencesStorage({Future<SharedPreferences>? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;

  @override
  Future<int?> readDefaultTaskMinutes() async =>
      (await _preferences).getInt(defaultTaskMinutesKey);

  @override
  Future<void> writeDefaultTaskMinutes(int value) async {
    final written =
        await (await _preferences).setInt(defaultTaskMinutesKey, value);
    if (!written) throw const PreferencesStorageWriteException();
  }
}
