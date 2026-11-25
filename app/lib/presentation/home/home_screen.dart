import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/account.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/greeting.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_center.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
import '../session/follow_controller.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';

class HomeData {
  const HomeData(this.sessions, this.nextSessionId);

  final List<Session> sessions;
  final String? nextSessionId;
}

/// Beranda: students see the sessions they follow today (`/me/today`);
/// lecturers/officers see today's sessions they may edit (`/sessions?editable=1`).
class HomeController extends AsyncController<HomeData> {
  HomeController(this._repo, this._account, this._follows, super.clock) {
    _follows.addListener(load);
  }

  final SessionRepository _repo;
  final Account _account;
  final FollowController _follows;

  @override
  bool isEmpty(HomeData value) => value.sessions.isEmpty;

  @override
  Future<Result<HomeData>> fetch() async {
    if (!_account.isEditor) {
      final r = await _repo.today();
      return switch (r) {
        Success(:final value) => Success(
          HomeData(value.sessions, value.nextSessionId),
        ),
        Failure(:final failure) => Failure(failure),
      };
    }
    final r = await _repo.onDate(clock.now(), editableOnly: true);
    return switch (r) {
      Success(:final value) => Success(
        HomeData(
          value,
          value
              .where((s) => !s.isCancelled && s.end.isAfter(clock.now()))
              .firstOrNull
              ?.id,
        ),
      ),
      Failure(:final failure) => Failure(failure),
    };
  }

  @override
  void dispose() {
    _follows.removeListener(load);
    super.dispose();
  }
}

/// image/ui-ux/beranda.png.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenMenu});

  /// Hamburger button (opens the account menu).
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account!;
    return ChangeNotifierProvider(
      key: ValueKey(account.id),
      create: (c) => HomeController(
        c.read<SessionRepository>(),
        account,
        c.read<FollowController>(),
        c.read<Clock>(),
      )..load(),
      child: _HomeView(account: account, onOpenMenu: onOpenMenu),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.account, this.onOpenMenu});

  final Account account;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final unread = context.watch<NotificationCenter>().unread;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: SearchPill(
                    key: const Key('home-search'),
                    hint: 'Cari dosen',
                    onTap: () => openSearch(context),
                  ),
                ),
                IconButton(
                  key: const Key('nav-notifications'),
                  tooltip: 'Notifikasi',
                  iconSize: 28,
                  onPressed: () => openNotifications(context),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none),
                  ),
                ),
                IconButton(
                  key: const Key('home-menu'),
                  tooltip: 'Menu',
                  iconSize: 28,
                  onPressed: onOpenMenu,
                  icon: const Icon(Icons.menu),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingFor(account),
                          key: const Key('home-greeting'),
                          style: AppFonts.sansStyle(
                            18,
                            600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          account.role == UserRole.mahasiswa
                              ? '${account.subtitle} · ${account.points} poin'
                              : '${account.role.label} · ${account.subtitle}',
                          style: AppFonts.sansStyle(
                            14,
                            400,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionTitle(
                    'Sesi hari ini',
                    subtitle: account.isEditor
                        ? 'Sesi yang bisa Anda kelola'
                        : 'Sesi yang Anda ikuti',
                  ),
                  _TodayList(controller: controller, account: account),
                  const SizedBox(height: 32),
                  Image.asset(BrandAssets.lecturer, height: 150),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
                    child: Text(
                      'Dosen mengajar dengan tanggung jawab, disiplin, dan '
                      'integritas.',
                      textAlign: TextAlign.center,
                      style: AppFonts.sansStyle(16, 400, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  const _TodayList({required this.controller, required this.account});

  final HomeController controller;
  final Account account;

  @override
  Widget build(BuildContext context) {
    switch (controller.state) {
      case ViewLoading():
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            key: Key('state-loading'),
            child: CircularProgressIndicator(),
          ),
        );
      case ViewError(:final message):
        return InlineMessage(
          key: const Key('state-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat',
          message: message,
          actionLabel: 'Coba lagi',
          onAction: controller.load,
        );
      case ViewEmpty():
        return InlineMessage(
          key: const Key('state-empty'),
          icon: Icons.event_available_outlined,
          title: account.isEditor
              ? 'Tidak ada sesi yang Anda kelola hari ini'
              : 'Belum ada sesi diikuti hari ini',
          message: account.isEditor
              ? 'Lihat tanggal lain di tab Jadwal.'
              : 'Cari dosen, buka sesinya, lalu ketuk "Ikuti sesi".',
          actionLabel: account.isEditor ? null : 'Cari dosen',
          onAction: account.isEditor ? null : () async => openSearch(context),
        );
      case ViewData(:final data, :final fetchedAt, :final staleReason):
        return Column(
          children: [
            if (staleReason != null)
              FreshnessBanner(
                fetchedAt: fetchedAt,
                staleReason: staleReason,
                onRetry: controller.load,
              ),
            for (final s in data.sessions)
              SessionCard(
                session: s,
                highlight: s.id == data.nextSessionId,
                trailingBadge: (s.pendingReportCount ?? 0) > 0
                    ? _PendingBadge(count: s.pendingReportCount!)
                    : null,
                onTap: () async {
                  await openSessionDetail(context, s.id);
                  controller.load();
                },
              ),
          ],
        );
    }
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDD5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count laporan',
      style: AppFonts.sansStyle(12, 500, color: const Color(0xFF9A3412)),
    ),
  );
}

/// Small centred message used inside scrolling pages.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.icon),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(16, 600, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> openNotifications(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
