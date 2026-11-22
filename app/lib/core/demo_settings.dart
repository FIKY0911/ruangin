import 'package:flutter/foundation.dart';

import 'result.dart';

/// Demo-only knobs to make every screen state reachable without a backend:
/// artificial latency (loading state) and forced failures (error/stale state).
class DemoSettings extends ChangeNotifier {
  DemoSettings({this.latency = const Duration(milliseconds: 350)});

  Duration latency;
  bool _simulateFailure = false;

  bool get simulateFailure => _simulateFailure;

  set simulateFailure(bool value) {
    if (value == _simulateFailure) return;
    _simulateFailure = value;
    notifyListeners();
  }

  /// Called by local repositories before every read.
  Future<void> beforeRead() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_simulateFailure) {
      throw const AppFailure('Gagal memuat data (simulasi jaringan putus).');
    }
  }
}
