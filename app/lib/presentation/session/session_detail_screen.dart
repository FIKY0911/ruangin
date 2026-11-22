import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/session_service.dart';
import '../../domain/session_status.dart';
import '../auth/auth_controller.dart';
import '../edit/edit_session_screen.dart';
import '../widgets/async_state_view.dart';
import '../widgets/session_widgets.dart';
import 'follow_controller.dart';
import 'session_detail_controller.dart';

Future<void> openSessionDetail(BuildContext context, String sessionId) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(sessionId: sessionId),
    ));

/// P03 detail + P04 follow + P09 report + entry to P05 edit.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => SessionDetailController(
        sessionId: sessionId,
        account: c.read<AuthController>().account,
        sessions: c.read<SessionRepository>(),
        lecturers: c.read<LecturerRepository>(),
        reports: c.read<ReportRepository>(),
        service: c.read<SessionService>(),
        clock: c.read<Clock>(),
      )..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionDetailController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail sesi')),
      body: AsyncStateView<SessionDetail>(
        state: controller.state,
        onRetry: controller.load,
        emptyTitle: 'Sesi tidak ditemukan',
        builder: (context, detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final SessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.session;
    final theme = Theme.of(context);
    final controller = context.watch<SessionDetailController>();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.courseName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('${detail.lecturer.name} · Prodi kelas: ${s.prodi}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _InfoRow(icon: Icons.event, text: formatDate(s.start)),
        _InfoRow(
            icon: Icons.schedule,
            text: '${formatTimeRange(s.start, s.end)} · selesai ${formatTime(s.end)}'),
        _InfoRow(icon: Icons.meeting_room_outlined, text: s.room, key: const Key('detail-room')),
        const SizedBox(height: 12),
        _StatusCard(session: s),
        const SizedBox(height: 12),
        _FollowButton(sessionId: s.id),
        if (controller.canReport) ...[
          const SizedBox(height: 8),
          _ReportButton(
            alreadyReported: controller.hasReported,
            busy: controller.isReporting,
            onConfirmed: () async {
              final msg = await controller.reportEmptyRoom();
              if (context.mounted) _snack(context, msg);
            },
          ),
        ],
        if (controller.canEdit) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('edit-session'),
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Ubah sesi'),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => EditSessionScreen(session: s),
              ));
              controller.load();
            },
          ),
        ],
        if (detail.reports.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Laporan mahasiswa', style: theme.textTheme.titleMedium),
          for (final r in detail.reports)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_outlined),
              title: const Text('Ruang dilaporkan kosong'),
              subtitle: Text(
                  '${formatDateTime(r.createdAt)} · ${EmptyRoomReport.confirmationLabel}'),
            ),
          Text(
            'Laporan tidak mengubah status sesi sampai dikonfirmasi '
            'dosen/petugas.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        Text('Riwayat perubahan', style: theme.textTheme.titleMedium),
        for (final h in s.history.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(h.description),
            subtitle: Text('${formatDateTime(h.at)} · ${h.actor}'),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            StatusChip(session: session, key: const Key('detail-status')),
            const SizedBox(height: 8),
            Text(session.statusExplanation, style: theme.textTheme.bodySmall),
            const Divider(height: 20),
            Text('Sumber: ${session.source}', style: theme.textTheme.bodySmall),
            Text('Diperbarui: ${formatDateTime(session.updatedAt)}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(scheduleDisclaimer, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final follows = context.watch<FollowController>();
    final following = follows.isFollowing(sessionId);
    Future<void> toggle() async {
      final msg = await follows.toggle(sessionId);
      if (context.mounted) _snack(context, msg);
    }

    return following
        ? OutlinedButton.icon(
            key: const Key('unfollow-button'),
            onPressed: toggle,
            icon: const Icon(Icons.notifications_off_outlined),
            label: const Text('Berhenti ikuti sesi'),
          )
        : FilledButton.icon(
            key: const Key('follow-button'),
            onPressed: toggle,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Ikuti sesi'),
          );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.alreadyReported,
    required this.busy,
    required this.onConfirmed,
  });

  final bool alreadyReported;
  final bool busy;
  final Future<void> Function() onConfirmed;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Lapor ruang kosong?'),
        content: const Text(
            'Laporan akan diberi label "belum dikonfirmasi" dan dikabarkan '
            'ke pengikut sesi. Status sesi tidak berubah sampai '
            'dikonfirmasi dosen/petugas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kirim laporan')),
        ],
      ),
    );
    if (ok == true) await onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('report-empty'),
      icon: const Icon(Icons.report_outlined),
      label: Text(alreadyReported
          ? 'Sudah dilaporkan kosong (belum dikonfirmasi)'
          : 'Lapor ruang kosong'),
      onPressed: alreadyReported || busy ? null : () => _confirm(context),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
