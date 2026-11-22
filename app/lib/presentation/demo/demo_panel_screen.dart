import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/demo_settings.dart';
import '../../data/local/key_value_store.dart';
import '../notifications/notification_center.dart';
import 'demo_panel_controller.dart';
import '../session/follow_controller.dart';

/// Demo-only controls so testers can reach the "gagal muat" and
/// "data lama" states and reset local data. Not a product feature.
class DemoPanelScreen extends StatelessWidget {
  const DemoPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = context.watch<DemoSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Panel demo')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Semua data di aplikasi ini sintetis dan tersimpan lokal.'),
            subtitle: Text('Belum terhubung ke backend atau sistem kampus.'),
          ),
          SwitchListTile(
            key: const Key('toggle-failure'),
            title: const Text('Simulasi gagal muat'),
            subtitle: const Text(
                'Muat ulang layar (tarik ke bawah) untuk melihat state "gagal muat" '
                'atau "data lama".'),
            value: demo.simulateFailure,
            onChanged: (v) => demo.simulateFailure = v,
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset data demo'),
            subtitle: const Text('Hapus perubahan sesi, ikutan, notifikasi, laporan.'),
            onTap: () async {
              final msg = await DemoPanelController(
                settings: demo,
                store: context.read<KeyValueStore>(),
                follows: context.read<FollowController>(),
                notifications: context.read<NotificationCenter>(),
              ).resetData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
        ],
      ),
    );
  }
}
