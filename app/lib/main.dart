import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/clock.dart';
import 'core/demo_settings.dart';
import 'data/local/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(RuanginApp(
    dependencies: buildDependencies(
      store: SharedPreferencesStore(prefs),
      clock: const SystemClock(),
      demo: DemoSettings(),
    ),
  ));
}
