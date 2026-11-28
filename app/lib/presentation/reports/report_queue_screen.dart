import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/models/empty_room_report.dart';
import '../../data/repositories/repositories.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'report_queue_controller.dart';

Future<void> openReportQueue(BuildContext context, {String? sessionId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Laporan ruang kosong')),
          body: ReportQueueView(sessionId: sessionId),
        ),
      ),
    );

/// Laporan tab for lecturers/officers: reports on sessions they may edit,
/// filtered by status, with confirm/reject (same card style as the ui-ux
/// search results and Beranda cards).
class ReportQueueView extends StatelessWidget {
  const ReportQueueView({super.key, this.sessionId, this.header});

  final String? sessionId;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => ReportQueueController(
        c.read<ReportRepository>(),
        c.read<Clock>(),
        sessionId: sessionId,
      )..load(),
      child: Consumer<ReportQueueController>(
        builder: (context, controller, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?header,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (status, label) in [
                      (ReportStatus.pending, 'Menunggu'),
                      (ReportStatus.confirmed, 'Dikonfirmasi'),
                      (ReportStatus.rejected, 'Ditolak'),
                      (null, 'Semua'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('report-filter-${status?.name ?? 'all'}'),
                          label: Text(label),
                          selected: controller.status == status,
                          onSelected: (_) => controller.setStatus(status),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AsyncStateView<List<EmptyRoomReport>>(
                state: controller.state,
                onRetry: controller.load,
                emptyTitle: controller.status == ReportStatus.pending
                    ? 'Tidak ada laporan menunggu konfirmasi'
                    : 'Belum ada laporan',
                emptyMessage:
                    'Laporan ruang kosong dari mahasiswa untuk sesi yang bisa '
                    'Anda ubah muncul di sini.',
                builder: (context, reports) => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  itemCount: reports.length,
                  itemBuilder: (context, i) =>
                      _ReportCard(report: reports[i], controller: controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.controller});

  final EmptyRoomReport report;
  final ReportQueueController controller;

  Future<void> _act(BuildContext context, {required bool confirm}) async {
    final s = report.session;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(confirm ? 'Konfirmasi ruang kosong?' : 'Tolak laporan?'),
        content: Text(
          confirm
              ? 'Sesi ${s?.courseName ?? ''} akan berstatus "Batal". Semua '
                    'pelapor yang menunggu mendapat poin, dan pengikut sesi '
                    'menerima notifikasi resmi.'
              : 'Laporan ditandai ditolak. Jadwal dan status sesi tidak '
                    'berubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            key: const Key('confirm-resolve'),
            style: confirm
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirm ? 'Konfirmasi batal' : 'Tolak'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final msg = confirm
        ? await controller.confirm(report)
        : await controller.reject(report);
    if (context.mounted) showSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final s = report.session;
    final busy = controller.isBusy(report.id);
    final (bg, fg) = switch (report.status) {
      ReportStatus.pending => (
        const Color(0xFFFFEDD5),
        const Color(0xFF9A3412),
      ),
      ReportStatus.confirmed => (
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      ReportStatus.rejected => (
        const Color(0xFFE5E7EB),
        const Color(0xFF374151),
      ),
    };
    return SoftCard(
      key: Key('report-${report.id}'),
      onTap: s == null ? null : () => openSessionDetail(context, s.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s?.courseName ?? 'Sesi ${report.sessionId}',
                  style: AppFonts.sansStyle(17, 700, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.status.label,
                  style: AppFonts.sansStyle(12, 500, color: fg),
                ),
              ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 4),
            Text(
              '${formatShortDate(s.start)} · ${formatTimeRange(s.start, s.end)} · '
              '${s.place}',
              style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
            ),
            if (s.lecturer != null)
              Text(
                s.lecturer!.name,
                style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            'Dilaporkan ${report.reporterName ?? 'mahasiswa'} · '
            '${formatDateTime(report.createdAt)}'
            '${report.resolvedAt != null ? '\nDitinjau ${formatDateTime(report.resolvedAt!)}' : ''}',
            style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
          ),
          if (report.isPending) ...[
            const SizedBox(height: 10),
            if (busy) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('reject-${report.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: busy
                        ? null
                        : () => _act(context, confirm: false),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('confirm-${report.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      textStyle: AppFonts.sansStyle(16, 600),
                    ),
                    onPressed: busy ? null : () => _act(context, confirm: true),
                    child: const Text('Konfirmasi'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
