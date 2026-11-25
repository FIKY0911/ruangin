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
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'report_queue_screen.dart';

/// Laporan tab: the confirmation queue for lecturers/officers, and points +
/// report results for students.
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account!;
    return SafeArea(
      child: account.isEditor
          ? const ReportQueueView(
              header: SectionTitle(
                'Laporan ruang kosong',
                subtitle: 'Konfirmasi atau tolak laporan mahasiswa',
              ),
            )
          : const _StudentReports(),
    );
  }
}

/// Results of the student's own reports come as `reportResolved`
/// notifications (the API has no "my reports" list).
class _ResolvedReportsController
    extends AsyncController<List<AppNotification>> {
  _ResolvedReportsController(this._repo, super.clock);

  final NotificationRepository _repo;

  @override
  Future<Result<List<AppNotification>>> fetch() async {
    final r = await _repo.list();
    return switch (r) {
      Success(:final value) => Success(
        List.unmodifiable(
          value.items.where((n) => n.kind == NotificationKind.reportResolved),
        ),
      ),
      Failure(:final failure) => Failure(failure),
    };
  }
}

class _StudentReports extends StatelessWidget {
  const _StudentReports();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final account = auth.account!;
    return ChangeNotifierProvider(
      create: (c) {
        c.read<AuthController>().refreshAccount();
        return _ResolvedReportsController(
          c.read<NotificationRepository>(),
          c.read<Clock>(),
        )..load();
      },
      child: Consumer<_ResolvedReportsController>(
        builder: (context, controller, _) => RefreshIndicator(
          onRefresh: () async {
            await Future.wait([controller.load(), auth.refreshAccount()]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SectionTitle('Laporan & poin'),
              _PointsCard(points: account.points),
              const _HowItWorks(),
              const SectionTitle(
                'Hasil laporan Anda',
                padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
              ),
              switch (controller.state) {
                ViewLoading() => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                ViewError(:final message) => ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: const Text('Gagal memuat'),
                  subtitle: Text(message),
                  trailing: TextButton(
                    onPressed: controller.load,
                    child: const Text('Coba lagi'),
                  ),
                ),
                ViewEmpty() => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Belum ada laporan yang ditinjau. Laporan dikirim dari '
                    'halaman detail sesi saat ruang kelas kosong.',
                  ),
                ),
                ViewData(:final data, :final fetchedAt, :final staleReason) =>
                  Column(
                    children: [
                      if (staleReason != null)
                        FreshnessBanner(
                          fetchedAt: fetchedAt,
                          staleReason: staleReason,
                          onRetry: controller.load,
                        ),
                      for (final n in data)
                        SoftCard(
                          key: Key('resolved-${n.id}'),
                          onTap: n.sessionId.isEmpty
                              ? null
                              : () => openSessionDetail(context, n.sessionId),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                color: Color(0xFF15803D),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: AppFonts.sansStyle(
                                        15,
                                        600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if (n.body.isNotEmpty) n.body,
                                        formatDateTime(n.createdAt),
                                      ].join('\n'),
                                      style: AppFonts.sansStyle(
                                        13,
                                        400,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              },
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('points-card'),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0143F7), Color(0xFF3B6EFF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$points poin',
                  style: AppFonts.sansStyle(28, 700, color: Colors.white),
                ),
                Text(
                  'Dari laporan ruang kosong yang dikonfirmasi',
                  style: AppFonts.sansStyle(14, 400, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.schedule,
        'Lapor mulai 15 menit sebelum kelas sampai kelas selesai.',
      ),
      (
        Icons.label_outline,
        'Laporan berlabel "belum dikonfirmasi" dan tidak mengubah status sesi.',
      ),
      (
        Icons.verified_outlined,
        'Dosen/petugas mengonfirmasi: sesi jadi Batal dan Anda dapat poin.',
      ),
      (Icons.block_outlined, 'Maksimal 5 laporan per hari, 1 per sesi.'),
    ];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara kerja laporan',
            style: AppFonts.sansStyle(16, 600, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          for (final (icon, text) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppFonts.sansStyle(14, 400, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
