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
import '../widgets/ruangin_chrome.dart';
import '../widgets/ruangin_widgets.dart';
import 'follow_controller.dart';
import 'message_draft_sheet.dart';
import 'session_detail_controller.dart';

/// Opens full screen (root navigator), also from inside the Beranda tab.
Future<void> openSessionDetail(BuildContext context, String sessionId) =>
    Navigator.of(context, rootNavigator: true).push(
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
    final session = controller.session;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Detail sesi',
          style: AppFonts.sansStyle(20, 500, color: AppColors.ink),
        ),
      ),
      body: AsyncStateView<Session>(
        state: controller.state,
        onRetry: controller.load,
        emptyTitle: 'Sesi tidak ditemukan',
        showFreshness: false,
        builder: (context, session) => _DetailBody(session: session),
      ),
      bottomNavigationBar: session == null ? null : _BottomActions(session),
    );
  }
}

/// detail_sesi1.png / detail_sesi_tercatat.png.
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final controller = context.watch<SessionDetailController>();
    final lecturer = s.lecturer;
    final (statusColor, statusIcon) = statusStyle(s.status);
    final statusTime = s.attendance?.recordedAt ?? s.updatedAt;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          s.courseName,
          style: AppFonts.sansStyle(32, 700, color: AppColors.ink).copyWith(
            height: 1.15,
            decoration: s.isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        if (lecturer != null)
          InkWell(
            key: const Key('detail-lecturer'),
            onTap: () => openLecturer(context, lecturer.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                lecturer.name,
                style: AppFonts.sansStyle(
                  20,
                  400,
                  color: const Color(0xFF6B7080),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          key: const Key('detail-status'),
          children: [
            Icon(statusIcon, color: statusColor, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.statusShortLabel,
                style: AppFonts.sansStyle(22, 700, color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${s.attendance?.source ?? s.source} · ${formatTime(statusTime)}',
          style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          '${s.statusExplanation} $scheduleDisclaimer',
          style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        _InfoGrid(session: s),
        if (controller.canEdit && controller.pendingReports > 0) ...[
          const SizedBox(height: 16),
          _PendingReportsBanner(
            count: controller.pendingReports,
            onReview: () async {
              await openReportQueue(context, sessionId: s.id);
              controller.load();
            },
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.history, size: 28, color: AppColors.ink),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Riwayat perubahan',
                style: AppFonts.sansStyle(20, 600, color: AppColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.history.isEmpty)
          Text(
            'Belum ada perubahan.',
            style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
          ),
        for (final h in s.history.reversed) _HistoryCard(entry: h),
        const SizedBox(height: 16),
        if (controller.canEdit)
          OutlinedButton.icon(
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
        if (!s.isCancelled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('message-draft'),
            icon: const Icon(Icons.content_copy_outlined),
            label: const Text('Salin usulan pesan ke dosen'),
            onPressed: () => showMessageDraftSheet(context, controller),
          ),
        ],
      ],
    );
  }
}

/// 2×2 card: Jam · Tanggal / Ruang · Program studi.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    Widget cell(IconData icon, String label, String value, {Key? key}) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: AppColors.muted),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                key: key,
                style: AppFonts.sansStyle(19, 700, color: AppColors.ink),
              ),
            ],
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: softCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: cell(
                    Icons.schedule,
                    'Jam',
                    formatTimeRange(s.start, s.end),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFDADCE3)),
                Expanded(
                  child: cell(
                    Icons.event_outlined,
                    'Tanggal',
                    formatShortDate(s.start),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: Color(0xFFDADCE3),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: cell(
                    Icons.layers_outlined,
                    'Ruang',
                    s.room,
                    key: const Key('detail-room'),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFDADCE3)),
                Expanded(
                  child: cell(Icons.school_outlined, 'Program studi', s.prodi),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final ChangeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softCardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E6EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz, color: AppColors.muted),
            ),
            const VerticalDivider(width: 28, color: Color(0xFFD5D7DE)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.description,
                    style: AppFonts.sansStyle(16, 600, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      formatDateTime(entry.at),
                      if (entry.actor.isNotEmpty) entry.actor,
                    ].join(' · '),
                    style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned bottom: big blue "Ikuti" / "✓ Diikuti", then red "Lapor ruang
/// kosong" for students.
class _BottomActions extends StatelessWidget {
  const _BottomActions(this.session);

  final Session session;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionDetailController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FollowButton(sessionId: session.id),
            if (controller.canReport)
              _ReportButton(
                session: session,
                myReport: controller.myReport,
                busy: controller.isReporting,
                onConfirmed: () async {
                  final msg = await controller.reportEmptyRoom();
                  if (context.mounted) showSnack(context, msg);
                },
              ),
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

    return FilledButton(
      key: Key(following ? 'unfollow-button' : 'follow-button'),
      style: primaryButtonStyle(),
      onPressed: toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (following) ...[
            const Icon(Icons.check, size: 24),
            const SizedBox(width: 8),
          ],
          Text(following ? 'Diikuti' : 'Ikuti'),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton(
        key: const Key('report-empty'),
        style: TextButton.styleFrom(
          foregroundColor: statusRed,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size.fromHeight(48),
          textStyle: AppFonts.sansStyle(19, 600),
        ),
        onPressed: r != null || busy
            ? null
            : () async {
                if (await showReportSheet(context, session) == true) {
                  await onConfirmed();
                }
              },
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Lapor_Ruang_Kosong1.png: confirmation bottom sheet.
Future<bool?> showReportSheet(BuildContext context, Session session) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            key: const Key('report-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lapor ruang kosong',
                style: AppFonts.sansStyle(26, 700, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Sebagai mahasiswa, kamu melaporkan ${session.room} kosong.',
                textAlign: TextAlign.center,
                style: AppFonts.sansStyle(18, 400, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: softCardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.ink),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Belum dikonfirmasi hingga dicek petugas.',
                        style: AppFonts.sansStyle(
                          15,
                          400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('confirm-report'),
                style: primaryButtonStyle(),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Kirim laporan'),
              ),
              TextButton(
                key: const Key('cancel-report'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: AppFonts.sansStyle(19, 600),
                ),
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );

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
