import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../session/follow_controller.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'timeline_controller.dart';

Future<void> openLecturer(BuildContext context, String lecturerId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LecturerProfileScreen(lecturerId: lecturerId),
      ),
    );

/// P02 — image/ui-ux/profil.png: lecturer header, day picker, timeline of the
/// selected day across all prodi.
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(lecturer: data),
            const _DayPicker(),
            const Expanded(child: _Timeline()),
          ],
        ),
        final state => Column(
          children: [
            const _HeaderBar(),
            Expanded(
              child: AsyncStateView<Lecturer>(
                state: state,
                onRetry: lecturer.load,
                emptyTitle: 'Dosen tidak ditemukan',
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      },
    );
  }
}

const _headerGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFD3E2FB), Color(0xFFE6EEFC)],
);

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({this.extra = 0});

  /// Extra gradient below the title row (room for the avatar).
  final double extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _headerGradient),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56 + extra,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const BackButton(),
                  Text(
                    'Profil dosen',
                    style: AppFonts.sansStyle(20, 500, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: _HeaderBar(extra: 40),
            ),
            Positioned(
              bottom: 0,
              child: InitialsAvatar(name: lecturer.name, size: 96, border: 4),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                lecturer.name,
                key: const Key('lecturer-name'),
                textAlign: TextAlign.center,
                style: AppFonts.sansStyle(24, 700, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                lecturer.prodi,
                style: AppFonts.sansStyle(16, 400, color: AppColors.muted),
              ),
              Text(
                '${lecturer.faculty} · Timeline gabungan semua prodi',
                textAlign: TextAlign.center,
                style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Month heading + a strip of day chips (two weeks from this Monday).
class _DayPicker extends StatelessWidget {
  const _DayPicker();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimelineController>();
    final today = dateOnly(context.read<Clock>().now());
    final selected = controller.date;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = [
      for (var i = 0; i < 14; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    if (!days.any((d) => isSameDay(d, selected))) days.insert(0, selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[selected.month - 1]} ${selected.year}',
                  style: AppFonts.sansStyle(22, 700, color: AppColors.ink),
                ),
              ),
              IconButton(
                key: const Key('pick-date'),
                tooltip: 'Pilih tanggal',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: today.subtract(const Duration(days: 60)),
                    lastDate: today.add(const Duration(days: 120)),
                  );
                  if (picked != null) controller.selectDate(picked);
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = days[i];
              final active = isSameDay(d, selected);
              return InkWell(
                key: Key('day-${isoDate(d)}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => controller.selectDate(d),
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? AppColors.accent
                          : const Color(0xFFE3E4EA),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayShort[d.weekday - 1],
                        style: AppFonts.sansStyle(
                          14,
                          400,
                          color: active ? Colors.white : AppColors.ink,
                        ),
                      ),
                      Text(
                        '${d.day}',
                        style: AppFonts.sansStyle(
                          22,
                          700,
                          color: active ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
            isSameDay(selected, today)
                ? 'Sesi hari ini'
                : 'Sesi ${formatDate(selected)}',
            key: const Key('timeline-date'),
            style: AppFonts.sansStyle(22, 700, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimelineController>();
    final followed = context.watch<FollowController>().followed;
    return AsyncStateView<List<Session>>(
      state: controller.state,
      onRetry: controller.load,
      emptyTitle: 'Tidak ada jadwal mengajar di tanggal ini',
      emptyMessage: 'Coba tanggal lain.',
      emptyImage: BrandAssets.lecturer,
      showFreshness: false,
      builder: (context, sessions) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: sessions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 20, endIndent: 20),
        itemBuilder: (context, i) => SessionRow(
          session: sessions[i],
          isFollowed: followed.contains(sessions[i].id),
          onTap: () async {
            await openSessionDetail(context, sessions[i].id);
            controller.load();
          },
        ),
      ),
    );
  }
}
