import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/result.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_center.dart';
import '../widgets/ruangin_widgets.dart';

/// Demo panel (petugas only), backed by the backend's `/demo/*` endpoints
/// (enabled with RUANGIN_DEMO_MODE=true). Simulates the campus attendance
/// feed and the early-warning scheduler. Not a product feature.
class DemoPanelScreen extends StatefulWidget {
  const DemoPanelScreen({super.key});

  @override
  State<DemoPanelScreen> createState() => _DemoPanelScreenState();
}

class _DemoPanelScreenState extends State<DemoPanelScreen> {
  String? _running;

  Future<void> _run(
    String key,
    Future<String> Function() action, {
    Future<bool> Function()? confirm,
  }) async {
    if (confirm != null && !await confirm()) return;
    if (!mounted) return;
    setState(() => _running = key);
    final msg = await action();
    if (!mounted) return;
    setState(() => _running = null);
    showSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final demo = context.read<DemoRepository>();
    final notifications = context.read<NotificationCenter>();

    Widget tile({
      required String key,
      required IconData icon,
      required String title,
      required String subtitle,
      required Future<String> Function() action,
      Future<bool> Function()? confirm,
    }) => ListTile(
      key: Key(key),
      leading: _running == key
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      enabled: _running == null,
      onTap: () => _run(key, action, confirm: confirm),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Panel demo')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Data jadwal sintetis dari server Ruangin.'),
            subtitle: Text(
              'Panel ini hanya aktif jika server berjalan dengan '
              'RUANGIN_DEMO_MODE=true.',
            ),
          ),
          tile(
            key: 'demo-attendance',
            icon: Icons.how_to_reg_outlined,
            title: 'Simulasi batch absensi',
            subtitle:
                'Catat kehadiran semua sesi dalam cakupan yang sudah '
                'mulai hari ini dan belum tercatat.',
            action: () async {
              final r = await demo.attendanceBatch();
              await notifications.refresh();
              return switch (r) {
                Success(:final value) =>
                  '$value sesi tercatat dari sinkron absensi.',
                Failure(:final failure) => failure.message,
              };
            },
          ),
          tile(
            key: 'demo-early-warnings',
            icon: Icons.warning_amber_rounded,
            title: 'Jalankan peringatan dini',
            subtitle:
                'Kirim peringatan ke pengikut sesi berikutnya jika sesi '
                'dosen hari ini belum terkonfirmasi atau dilaporkan kosong.',
            action: () async {
              final r = await demo.runEarlyWarnings();
              await notifications.refresh();
              return switch (r) {
                Success(:final value) => '$value peringatan dini dikirim.',
                Failure(:final failure) => failure.message,
              };
            },
          ),
          tile(
            key: 'demo-reset',
            icon: Icons.restart_alt,
            title: 'Reset data demo',
            subtitle:
                'Hapus semua perubahan dan isi ulang jadwal hari ini. '
                'Semua akun akan keluar.',
            confirm: () async =>
                await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset data demo?'),
                    content: const Text(
                      'Semua perubahan, ikutan, laporan, dan '
                      'notifikasi di server dihapus. Semua akun keluar.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        key: const Key('confirm-reset'),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ) ==
                true,
            action: () async {
              final auth = context.read<AuthController>();
              final nav = Navigator.of(context);
              final r = await demo.reset();
              if (r case Success(:final value)) {
                nav.popUntil((route) => route.isFirst);
                await auth.logout();
                return value;
              }
              return (r as Failure).failure.message;
            },
          ),
        ],
      ),
    );
  }
}
