import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    RuanginApp(
      dependencies: buildDependencies(
        store: SharedPreferencesStore(prefs),
        httpClient: http.Client(),
      ),
    ),
  );
}
