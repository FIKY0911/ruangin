import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../app_config_controller.dart';
import '../session/follow_controller.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'attendance_controller.dart';
import 'attendance_history_screen.dart';
import 'timeline_controller.dart';

Future<void> openLecturer(BuildContext context, String lecturerId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LecturerProfileScreen(lecturerId: lecturerId),
      ),
    );

/// P02 — image/ui-ux/Profil_Dosen.png: blue header, "Ikuti" (follow the
/// lecturer), attendance summary for the semester, week strip and the
/// selected day's sessions across all prodi.
class LecturerProfileScreen extends StatelessWidget {
  const LecturerProfileScreen({super.key, required this.lecturerId});

  final String lecturerId;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => LecturerController(
            c.read<LecturerRepository>(),
            lecturerId,
            c.read<Clock>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (c) => TimelineController(
            c.read<SessionRepository>(),
            lecturerId,
            c.read<Clock>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (c) => SemesterAttendanceController(
            c.read<LecturerRepository>(),
            lecturerId,
            c.read<Clock>(),
          )..load(),
        ),
      ],
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final lecturer = context.watch<LecturerController>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: switch (lecturer.state) {
        ViewData(:final data) => Column(
          children: [
            const _TopBar(),
            Expanded(child: _Sheet(lecturer: data)),
          ],
        ),
        final state => Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: AsyncStateView<Lecturer>(
                  state: state,
                  onRetry: lecturer.load,
                  emptyTitle: 'Dosen tidak ditemukan',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

/// Pinned blue row: back + "Profil dosen".
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.accent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              Flexible(
                child: Text(
                  'Profil dosen',
                  style: AppFonts.sansStyle(20, 500, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name + prodi on blue (scrolls with the page).
class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 150, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lecturer.name,
            key: const Key('lecturer-name'),
            style: AppFonts.sansStyle(30, 700, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            lecturer.prodi,
            style: AppFonts.sansStyle(20, 400, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Below the pinned top bar everything scrolls: name on blue, white sheet with rounded top
/// and the square initials avatar on its edge, then the content.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<TimelineController>().load(),
          context.read<SemesterAttendanceController>().load(),
          context.read<LecturerController>().load(),
        ]);
      },
      child: ListView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: AppColors.accent,
                    child: _NameBlock(lecturer: lecturer),
                  ),
                  Container(
                    height: 32,
                    color: AppColors.accent,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: -30,
                right: 20,
                child: _SquareAvatar(name: lecturer.name),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 150, 0),
            child: Text(
              '${lecturer.faculty} · Timeline gabungan semua prodi',
              style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
            ),
          ),
          const _FollowLecturerButton(),
          const _AttendanceSummary(),
          const _WeekPicker(),
          const _Timeline(),
        ],
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 116,
    height: 116,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: softBlue,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Text(
      initialsOf(name),
      style: AppFonts.sansStyle(44, 700, color: AppColors.accent),
    ),
  );
}

/// Outlined "Ikuti" / "Diikuti" (Profil_Dosen.png): follow every session of
/// this lecturer.
class _FollowLecturerButton extends StatelessWidget {
  const _FollowLecturerButton();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LecturerController>();
    final lecturer = controller.value!;
    final following = lecturer.isFollowed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 150, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: const Key('follow-lecturer'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(140, 44),
            foregroundColor: following ? Colors.white : AppColors.accent,
            backgroundColor: following ? AppColors.accent : Colors.white,
            side: const BorderSide(color: AppColors.accent, width: 1.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: controller.isTogglingFollow
              ? null
              : () async {
                  final follows = context.read<FollowController>();
                  final msg = await controller.toggleFollow();
                  // "Sesi hari ini" on Beranda includes followed lecturers.
                  await follows.reload();
                  if (context.mounted && msg.isNotEmpty) {
                    showSnack(context, msg);
                  }
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (following) ...[
                const Icon(Icons.check, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                following ? 'Diikuti' : 'Ikuti',
                style: AppFonts.sansStyle(17, 700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Kehadiran semester ini · Tercatat di X dari Y sesi" + "Lihat riwayat".
class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SemesterAttendanceController>();
    final lecturer = context.read<LecturerController>().value!;
    final simulated = context.watch<AppConfigController>().simulatedData;
    final data = switch (controller.state) {
      ViewData(:final data) => data,
      _ => null,
    };
    final summary = data?.summary;
    final ink = AppFonts.sansStyle(19, 400, color: AppColors.ink);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kehadiran semester ini',
                  style: AppFonts.sansStyle(17, 700, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                switch (controller.state) {
                  ViewLoading() => Text('Memuat…', style: ink),
                  ViewError(:final message) => Text(
                    message,
                    key: const Key('attendance-summary'),
                    style: ink.copyWith(color: AppColors.muted, fontSize: 16),
                  ),
                  _ =>
                    summary == null || summary.counted == 0
                        ? Text(
                            'Belum ada sesi yang selesai',
                            key: const Key('attendance-summary'),
                            style: ink,
                          )
                        : Text.rich(
                            key: const Key('attendance-summary'),
                            TextSpan(
                              text: 'Tercatat di ',
                              children: [
                                TextSpan(
                                  text:
                                      '${summary.tercatat} dari '
                                      '${summary.counted} sesi',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            style: ink,
                          ),
                },
                const SizedBox(height: 2),
                Text(
                  [
                    data?.semester.name ?? 'Sesi yang sudah lewat',
                    if (simulated) 'Data simulasi',
                  ].join(' · '),
                  key: const Key('attendance-caption'),
                  style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('open-attendance'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                  value: controller,
                  child: AttendanceHistoryScreen(lecturer: lecturer),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lihat riwayat', style: AppFonts.sansStyle(16, 600)),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _dayLong = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu', //
];

/// Month heading with ‹ › (previous / next week) and the weekday strip.
/// Saturday and Sunday appear only when one of them is selected.
class _WeekPicker extends StatelessWidget {
  const _WeekPicker();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimelineController>();
    final selected = controller.date;
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = [
      for (var i = 0; i < (selected.weekday > 5 ? 7 : 5); i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final compact = days.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[selected.month - 1]} ${selected.year}',
                  style: AppFonts.sansStyle(20, 700, color: AppColors.ink),
                ),
              ),
              IconButton(
                key: const Key('week-prev'),
                tooltip: 'Minggu sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.selectDate(
                  selected.subtract(const Duration(days: 7)),
                ),
              ),
              IconButton(
                key: const Key('week-next'),
                tooltip: 'Minggu berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => controller.selectDate(
                  selected.add(const Duration(days: 7)),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: softCardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: _DayChip(
                    day: d,
                    active: isSameDay(d, selected),
                    compact: compact,
                    onTap: () => controller.selectDate(d),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Sesi ${_dayLong[selected.weekday - 1]}, ${formatShortDate(selected)}',
            key: const Key('timeline-date'),
            style: AppFonts.sansStyle(24, 700, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final DateTime day;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.ink;
    return InkWell(
      key: Key('day-${isoDate(day)}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _dayShort[day.weekday - 1],
              style: AppFonts.sansStyle(15, 500, color: color),
            ),
            Text(
              '${day.day}',
              style: AppFonts.sansStyle(compact ? 20 : 24, 700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sessions of the selected day; lives inside the sheet's ListView.
class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimelineController>();
    final followed = context.watch<FollowController>().followed;
    final homeProdi = context.read<LecturerController>().value?.prodi;
    Widget emptyMessage(String title, String text, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        children: [
          Image.asset(BrandAssets.lecturer, height: 120),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(17, 600, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
          ),
        ],
      ),
    );
    return switch (controller.state) {
      ViewLoading() => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          key: Key('state-loading'),
          child: CircularProgressIndicator(),
        ),
      ),
      ViewError(:final message) => _ErrorMessage(
        message: message,
        onRetry: controller.load,
      ),
      ViewEmpty() => emptyMessage(
        'Tidak ada jadwal mengajar di tanggal ini',
        'Coba tanggal lain.',
        key: const Key('state-empty'),
      ),
      ViewData(:final data, :final fetchedAt, :final staleReason) => Column(
        children: [
          if (staleReason != null)
            FreshnessBanner(
              fetchedAt: fetchedAt,
              staleReason: staleReason,
              onRetry: controller.load,
            ),
          for (final s in data)
            _SessionCard(
              session: s,
              homeProdi: homeProdi,
              isFollowed: followed.contains(s.id),
              onTap: () async {
                await openSessionDetail(context, s.id);
                controller.load();
              },
            ),
        ],
      ),
    };
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('state-error'),
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.icon),
        const SizedBox(height: 8),
        Text(
          'Gagal memuat',
          style: AppFonts.sansStyle(17, 600, color: AppColors.ink),
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

/// Grey session card from Profil_Dosen.png.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.homeProdi,
    required this.isFollowed,
    required this.onTap,
  });

  final Session session;
  final String? homeProdi;
  final bool isFollowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: softCardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('session-${s.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.courseName,
                        style: AppFonts.sansStyle(19, 700, color: AppColors.ink)
                            .copyWith(
                              decoration: s.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          formatTimeRange(s.start, s.end),
                          s.place,
                          if (s.prodi != homeProdi) 'Prodi ${s.prodi}',
                        ].join(' · '),
                        style: AppFonts.sansStyle(
                          16,
                          400,
                          color: const Color(0xFF3B3F55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusLine(session: s, short: true, size: 16),
                    ],
                  ),
                ),
                if (isFollowed)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.notifications_active,
                      size: 20,
                      color: AppColors.accent,
                      semanticLabel: 'Diikuti',
                    ),
                  ),
                const Icon(Icons.chevron_right, color: AppColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
