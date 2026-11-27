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
import '../widgets/ruangin_chrome.dart';
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

/// P06 + P11 — image/ui-ux/notifikasi_revisi.png (Semua) and
/// notifikasi_belum_dibaca.png (Belum dibaca). Tapping opens the session.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => NotificationsController(
        c.read<NotificationRepository>(),
        c.read<Clock>(),
      )..load(),
      child: Consumer<NotificationsController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              const WaveBackground(heightFactor: 0.18),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(unread: controller.unreadCount),
                    _Filters(
                      unreadOnly: _unreadOnly,
                      onChanged: (v) => setState(() => _unreadOnly = v),
                      onReadAll: controller.unreadCount == 0
                          ? null
                          : () async {
                              final msg = await controller.markAllRead();
                              if (context.mounted) showSnack(context, msg);
                            },
                    ),
                    Expanded(
                      child: AsyncStateView<List<AppNotification>>(
                        state: controller.state,
                        onRetry: controller.load,
                        showFreshness: false,
                        emptyTitle: 'Belum ada notifikasi',
                        emptyMessage:
                            'Ikuti sesi agar dapat kabar saat ruang, jam, atau '
                            'status berubah.',
                        builder: (context, items) => _GroupedList(
                          items: [
                            for (final n in items)
                              if (!_unreadOnly || !n.isRead) n,
                          ],
                          now: context.read<Clock>().now(),
                          controller: controller,
                        ),
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 20, 8),
      child: Row(
        children: [
          const BackButton(),
          Flexible(
            child: Text(
              'Notifikasi',
              style: AppFonts.sansStyle(28, 500, color: AppColors.ink),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 10),
            Container(
              key: const Key('unread-count'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: softBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$unread',
                style: AppFonts.sansStyle(16, 500, color: AppColors.ink),
              ),
            ),
          ],
          const Spacer(),
          const RuanginLogo(height: 30),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.unreadOnly,
    required this.onChanged,
    required this.onReadAll,
  });

  final bool unreadOnly;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onReadAll;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap, Key key) =>
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Material(
            color: selected ? softBlue : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected ? softBlue : const Color(0xFFDADCE3),
              ),
            ),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text(
                  label,
                  style: AppFonts.sansStyle(17, 500, color: AppColors.ink),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(
                    'Semua',
                    !unreadOnly,
                    () => onChanged(false),
                    const Key('filter-all'),
                  ),
                  chip(
                    'Belum dibaca',
                    unreadOnly,
                    () => onChanged(true),
                    const Key('filter-unread'),
                  ),
                ],
              ),
            ),
          ),
          if (onReadAll != null)
            IconButton(
              key: const Key('read-all'),
              tooltip: 'Tandai semua dibaca',
              icon: const Icon(Icons.done_all),
              onPressed: onReadAll,
            ),
        ],
      ),
    );
  }
}

/// "Hari ini" then "Sebelumnya".
class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.items,
    required this.now,
    required this.controller,
  });

  final List<AppNotification> items;
  final DateTime now;
  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final today = [
      for (final n in items)
        if (isSameDay(n.createdAt, now)) n,
    ];
    final earlier = [
      for (final n in items)
        if (!isSameDay(n.createdAt, now)) n,
    ];
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: AppFonts.sansStyle(20, 500, color: AppColors.ink),
      ),
    );
    Widget group(List<AppNotification> list) => Column(
      children: [
        for (final n in list) ...[
          NotificationTile(notification: n, controller: controller, now: now),
          const Divider(height: 1, indent: 20, endIndent: 20),
        ],
      ],
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (items.isEmpty)
          Padding(
            key: const Key('no-unread'),
            padding: const EdgeInsets.all(32),
            child: Text(
              'Semua notifikasi sudah dibaca.',
              textAlign: TextAlign.center,
              style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
            ),
          ),
        if (today.isNotEmpty) ...[heading('Hari ini'), group(today)],
        if (earlier.isNotEmpty) ...[heading('Sebelumnya'), group(earlier)],
      ],
    );
  }
}

/// Icon per kind, plus the caveat label for kinds that are not an official
/// change (a report is "belum dikonfirmasi", a warning changes nothing).
(IconData, String?) notificationStyle(AppNotification n) => switch (n.kind) {
  NotificationKind.sessionChanged =>
    n.title.toLowerCase().contains('batal')
        ? (Icons.event_busy_outlined, null)
        : (Icons.swap_horiz, null),
  NotificationKind.emptyRoomReport => (
    Icons.meeting_room_outlined,
    'Laporan mahasiswa · belum dikonfirmasi',
  ),
  NotificationKind.earlyWarning => (
    Icons.event_available_outlined,
    'Peringatan dini · cek lagi sebelum berangkat',
  ),
  NotificationKind.reportResolved => (Icons.verified_outlined, null),
};

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.controller,
    required this.now,
  });

  final AppNotification notification;
  final NotificationsController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, caveat) = notificationStyle(n);
    final when = isSameDay(n.createdAt, now)
        ? formatTime(n.createdAt)
        : formatShortDate(n.createdAt);
    return InkWell(
      key: Key('notification-${n.id}'),
      onTap: () async {
        await controller.markRead(n);
        if (context.mounted && n.sessionId.isNotEmpty) {
          await openSessionDetail(context, n.sessionId);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEEF2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF3B3F55), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppFonts.sansStyle(
                            18,
                            n.isRead ? 500 : 600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: AppFonts.sansStyle(
                          15,
                          400,
                          color: AppColors.ink,
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 10),
                        Container(
                          key: Key('unread-dot-${n.id}'),
                          margin: const EdgeInsets.only(top: 5),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B63F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: AppFonts.sansStyle(
                        15,
                        400,
                        color: const Color(0xFF3B3F55),
                      ),
                    ),
                  ],
                  if (caveat != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caveat,
                      key: Key('notification-kind-${n.kind.name}'),
                      style: AppFonts.sansStyle(
                        13,
                        500,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
