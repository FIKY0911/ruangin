import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/repositories.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import '../../core/view_state.dart';

class NotificationsController extends AsyncController<List<AppNotification>> {
  NotificationsController(this._repo, super.clock) {
    _sub = _repo.changes.listen((_) => load());
  }

  final NotificationRepository _repo;
  late final StreamSubscription<void> _sub;
  final Set<String> _reportedSeen = {};

  int get unreadCount => value?.where((n) => !n.isRead).length ?? 0;

  @override
  Future<Result<List<AppNotification>>> fetch() async {
    final r = await _repo.list();
    if (r case Success(:final value)) {
      // Mode uji: tell the server which notifications are now on screen.
      final fresh = [
        for (final n in value.items)
          if (_reportedSeen.add(n.id)) n.id,
      ];
      unawaited(_repo.markSeen(fresh));
    }
    return switch (r) {
      Success(:final value) => Success(value.items),
      Failure(:final failure) => Failure(failure),
    };
  }

  Future<void> markRead(AppNotification n) async {
    if (!n.isRead) await _repo.markRead(n.id);
  }

  Future<String> markAllRead() async => switch (await _repo.markAllRead()) {
    Success(:final value) =>
      value == 0
          ? 'Semua notifikasi sudah dibaca.'
          : '$value notifikasi ditandai dibaca.',
    Failure(:final failure) => failure.message,
  };

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// P06 + P11: in-app notifications; tapping opens the session detail.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => NotificationsController(
        c.read<NotificationRepository>(),
        c.read<Clock>(),
      )..load(),
      child: Consumer<NotificationsController>(
        builder: (context, controller, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi'),
            actions: [
              if (controller.unreadCount > 0)
                IconButton(
                  key: const Key('read-all'),
                  tooltip: 'Tandai semua dibaca',
                  icon: const Icon(Icons.done_all),
                  onPressed: () async {
                    final msg = await controller.markAllRead();
                    if (context.mounted) showSnack(context, msg);
                  },
                ),
            ],
          ),
          body: AsyncStateView<List<AppNotification>>(
            state: controller.state,
            onRetry: controller.load,
            emptyTitle: 'Belum ada notifikasi',
            emptyMessage: 'Ikuti sesi agar dapat kabar saat ruang, jam, atau status berubah.',
            builder: (context, items) => ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => NotificationTile(
                notification: items[i],
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual per kind: official change, unconfirmed report, early warning,
/// report result.
(IconData, Color, String) notificationStyle(NotificationKind kind) =>
    switch (kind) {
      NotificationKind.sessionChanged => (
        Icons.update,
        AppColors.accent,
        'Perubahan resmi',
      ),
      NotificationKind.emptyRoomReport => (
        Icons.report_outlined,
        const Color(0xFFC2410C),
        'Laporan mahasiswa · belum dikonfirmasi',
      ),
      NotificationKind.earlyWarning => (
        Icons.warning_amber_rounded,
        const Color(0xFFB45309),
        'Peringatan dini · cek lagi sebelum berangkat',
      ),
      NotificationKind.reportResolved => (
        Icons.verified_outlined,
        const Color(0xFF15803D),
        'Hasil laporan Anda',
      ),
    };

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.controller,
  });

  final AppNotification notification;
  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color, label) = notificationStyle(n.kind);
    return Material(
      color: n.isRead ? Colors.transparent : const Color(0xFFEFF4FF),
      child: InkWell(
        key: Key('notification-${n.id}'),
        onTap: () async {
          await controller.markRead(n);
          if (context.mounted && n.sessionId.isNotEmpty) {
            await openSessionDetail(context, n.sessionId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      key: Key('notification-kind-${n.kind.name}'),
                      style: AppFonts.sansStyle(12, 600, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.title,
                      style: AppFonts.sansStyle(
                        15,
                        n.isRead ? 400 : 600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (n.body.isNotEmpty)
                      Text(
                        n.body,
                        style: AppFonts.sansStyle(
                          14,
                          400,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(n.createdAt),
                      style: AppFonts.sansStyle(12, 400, color: AppColors.icon),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
