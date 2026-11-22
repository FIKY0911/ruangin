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
import '../widgets/async_state_view.dart';
import '../widgets/session_widgets.dart';
import 'timeline_controller.dart';

/// P02: lecturer profile + timeline per date.
class LecturerProfileScreen extends StatelessWidget {
  const LecturerProfileScreen({super.key, required this.lecturerId});

  final String lecturerId;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => LecturerController(
              c.read<LecturerRepository>(), lecturerId, c.read<Clock>())
            ..load(),
        ),
        ChangeNotifierProvider(
          create: (c) => TimelineController(
              c.read<SessionRepository>(), lecturerId, c.read<Clock>())
            ..load(),
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
      appBar: AppBar(title: const Text('Profil dosen')),
      body: switch (lecturer.state) {
        ViewData(:final data) => Column(
            children: [
              _Header(lecturer: data),
              const _DateBar(),
              const Expanded(child: _Timeline()),
            ],
          ),
        final state => AsyncStateView<Lecturer>(
            state: state,
            onRetry: lecturer.load,
            emptyTitle: 'Dosen tidak ditemukan',
            builder: (_, _) => const SizedBox.shrink(),
          ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(BrandAssets.lecturer,
                width: 64, height: 88, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecturer.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Prodi asal: ${lecturer.prodi}'),
                Text(lecturer.faculty, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Timeline gabungan semua prodi',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimelineController>();
    final today = dateOnly(context.read<Clock>().now());
    final date = controller.date;
    final label = isSameDay(date, today) ? 'Hari ini · ${formatDate(date)}' : formatDate(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('prev-day'),
            tooltip: 'Hari sebelumnya',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => controller
                .selectDate(DateTime(date.year, date.month, date.day - 1)),
          ),
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(label, key: const Key('timeline-date')),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: today.subtract(const Duration(days: 30)),
                  lastDate: today.add(const Duration(days: 60)),
                );
                if (picked != null) controller.selectDate(picked);
              },
            ),
          ),
          IconButton(
            key: const Key('next-day'),
            tooltip: 'Hari berikutnya',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => controller
                .selectDate(DateTime(date.year, date.month, date.day + 1)),
          ),
        ],
      ),
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
      builder: (context, sessions) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: sessions.length,
        itemBuilder: (context, i) => SessionTile(
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
