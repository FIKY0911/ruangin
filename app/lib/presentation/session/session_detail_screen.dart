import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/session_status.dart';
import '../auth/auth_controller.dart';
import '../edit/edit_session_screen.dart';
import '../lecturer/lecturer_profile_screen.dart';
import '../reports/report_queue_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import '../widgets/session_widgets.dart';
import 'follow_controller.dart';
import 'message_draft_sheet.dart';
import 'session_detail_controller.dart';

Future<void> openSessionDetail(BuildContext context, String sessionId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(sessionId: sessionId),
      ),
    );

/// P03 detail + P04 follow + P09 report + P12 message draft + entry to P05
/// edit and the report queue for lecturers/officers.
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
        reports: c.read<ReportRepository>(),
        follows: c.read<FollowController>(),
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
      body: AsyncStateView<Session>(
        state: controller.state,
        onRetry: controller.load,
        emptyTitle: 'Sesi tidak ditemukan',
        builder: (context, session) => _DetailBody(session: session),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final theme = Theme.of(context);
    final controller = context.watch<SessionDetailController>();
    final lecturer = s.lecturer;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.courseName, style: AppFonts.serifStyle(26, 700)),
        const SizedBox(height: 6),
        if (lecturer != null)
          InkWell(
            key: const Key('detail-lecturer'),
            onTap: () => openLecturer(context, lecturer.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  InitialsAvatar(name: lecturer.name, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lecturer.name,
                      style: AppFonts.sansStyle(
                        16,
                        500,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text('Prodi kelas: ${s.prodi}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        _InfoRow(icon: Icons.event, text: formatDate(s.start)),
        _InfoRow(
          icon: Icons.schedule,
          text:
              '${formatTimeRange(s.start, s.end)} · selesai ${formatTime(s.end)}',
        ),
        _InfoRow(
          icon: Icons.meeting_room_outlined,
          text: s.room,
          key: const Key('detail-room'),
        ),
        const SizedBox(height: 12),
        _StatusCard(session: s),
        const SizedBox(height: 12),
        _FollowButton(sessionId: s.id),
        if (controller.canReport) ...[
          const SizedBox(height: 8),
          _ReportButton(
            session: s,
            myReport: controller.myReport,
            busy: controller.isReporting,
            onConfirmed: () async {
              final msg = await controller.reportEmptyRoom();
              if (context.mounted) showSnack(context, msg);
            },
          ),
        ],
        if (!s.isCancelled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('message-draft'),
            icon: const Icon(Icons.content_copy_outlined),
            label: const Text('Salin usulan pesan ke dosen'),
            onPressed: () => showMessageDraftSheet(context, controller),
          ),
        ],
        if (controller.canEdit) ...[
          if (controller.pendingReports > 0) ...[
            const SizedBox(height: 12),
            _PendingReportsBanner(
              count: controller.pendingReports,
              onReview: () async {
                await openReportQueue(context, sessionId: s.id);
                controller.load();
              },
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('edit-session'),
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Ubah sesi'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditSessionScreen(session: s),
                ),
              );
              controller.load();
            },
          ),
        ],
        const SizedBox(height: 20),
        Text('Riwayat perubahan', style: theme.textTheme.titleMedium),
        if (s.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Belum ada perubahan.',
              style: theme.textTheme.bodySmall,
            ),
          ),
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
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
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
            Text(
              'Diperbarui: ${formatDateTime(session.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
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
      if (context.mounted) showSnack(context, msg);
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
    required this.session,
    required this.myReport,
    required this.busy,
    required this.onConfirmed,
  });

  final Session session;
  final EmptyRoomReport? myReport;
  final bool busy;
  final Future<void> Function() onConfirmed;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Lapor ruang kosong?'),
        content: Text(
          'Laporkan hanya jika ${session.room} benar-benar kosong. Laporan '
          'diberi label "belum dikonfirmasi" dan dikabarkan ke pengikut '
          'sesi. Status sesi tidak berubah sampai dikonfirmasi '
          'dosen/petugas; jika dikonfirmasi Anda mendapat poin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('confirm-report'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kirim laporan'),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final r = myReport;
    if (r == null && session.isCancelled) return const SizedBox.shrink();
    final label = switch (r?.status) {
      null => 'Lapor ruang kosong',
      ReportStatus.pending => 'Sudah dilaporkan kosong (belum dikonfirmasi)',
      ReportStatus.confirmed =>
        r!.pointsAwarded > 0
            ? 'Laporan Anda dikonfirmasi · +${r.pointsAwarded} poin'
            : 'Laporan Anda dikonfirmasi',
      ReportStatus.rejected => 'Laporan Anda ditolak',
    };
    return OutlinedButton.icon(
      key: const Key('report-empty'),
      icon: Icon(switch (r?.status) {
        ReportStatus.confirmed => Icons.verified_outlined,
        ReportStatus.rejected => Icons.block_outlined,
        _ => Icons.report_outlined,
      }),
      label: Text(label, textAlign: TextAlign.center),
      onPressed: r != null || busy ? null : () => _confirm(context),
    );
  }
}

class _PendingReportsBanner extends StatelessWidget {
  const _PendingReportsBanner({required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pending-reports-banner'),
      color: const Color(0xFFFFEDD5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.report_outlined, color: Color(0xFF9A3412)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count laporan ruang kosong menunggu konfirmasi Anda.',
                style: AppFonts.sansStyle(
                  14,
                  500,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ),
            TextButton(onPressed: onReview, child: const Text('Tinjau')),
          ],
        ),
      ),
    );
  }
}
