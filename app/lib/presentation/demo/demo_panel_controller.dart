import '../../core/demo_settings.dart';
import '../../data/local/key_value_store.dart';
import '../../data/repositories/local_repositories.dart';
import '../notifications/notification_center.dart';
import '../session/follow_controller.dart';

/// Actions for the demo panel (not a product feature).
class DemoPanelController {
  DemoPanelController({
    required this.settings,
    required this._store,
    required this._follows,
    required this._notifications,
  });

  final DemoSettings settings;
  final KeyValueStore _store;
  final FollowController _follows;
  final NotificationCenter _notifications;

  Future<String> resetData() async {
    await resetDemoData(_store);
    await _follows.reload();
    await _notifications.refresh();
    return 'Data demo direset.';
  }
}
