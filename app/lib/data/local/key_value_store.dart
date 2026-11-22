import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistence port used by the local repositories.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}

extension KeyValueStoreJson on KeyValueStore {
  Object? readJson(String key) {
    final raw = getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> writeJson(String key, Object? value) =>
      setString(key, jsonEncode(value));
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    final ok = await _prefs.setString(key, value);
    if (!ok) throw StateError('Gagal menyimpan $key');
  }

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> clear() => _prefs.clear();
}

class InMemoryStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  String? getString(String key) => _data[key];

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}
