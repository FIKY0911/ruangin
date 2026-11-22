import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';
import '../session/session_detail_screen.dart';
import '../widgets/async_state_view.dart';

class NotificationsController extends AsyncController<List<AppNotification>> {
  NotificationsController(this._repo, this._userId, super.clock) {
    _sub = _repo.changes.listen((_) => load());
  }

  final NotificationRepository _repo;
  final String _userId;
  late final StreamSubscription<void> _sub;

  @override
  Future<Result<List<AppNotification>>> fetch() => _repo.forUser(_userId);

  Future<void> markRead(String id) => _repo.markRead(id);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// P06: in-app notifications; tapping opens the session detail.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthController>().account!;
    return ChangeNotifierProvider(
      create: (c) => NotificationsController(
          c.read<NotificationRepository>(), user.id, c.read<Clock>())
        ..load(),
      child: Consumer<NotificationsController>(
        builder: (context, controller, _) => AsyncStateView<List<AppNotification>>(
          state: controller.state,
          onRetry: controller.load,
          emptyTitle: 'Belum ada notifikasi',
          emptyMessage: 'Ikuti sesi agar dapat kabar saat ruang, jam, atau status berubah.',
          builder: (context, items) => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final isReport = n.kind == NotificationKind.emptyRoomReport;
              return ListTile(
                key: Key('notification-${n.id}'),
                tileColor: n.isRead
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                leading: Icon(isReport ? Icons.report_outlined : Icons.update,
                    color: isReport ? Colors.orange.shade800 : null),
                title: Text(n.title,
                    style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
                subtitle: Text('${n.body}\n${formatDateTime(n.createdAt)}'),
                isThreeLine: true,
                onTap: () async {
                  await controller.markRead(n.id);
                  if (context.mounted) await openSessionDetail(context, n.sessionId);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
