import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/session.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import 'attendance_controller.dart';

const _cardBlue = Color(0xFFF0F5FE);
const _red = Color(0xFFB91C3C);

/// image/ui-ux/riwayat_dosen.png, for the current week. Expects a
/// [WeekAttendanceController] above it (shared with the profile screen).
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key, required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WeekAttendanceController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Riwayat kehadiran',
          style: AppFonts.sansStyle(22, 600, color: AppColors.ink),
        ),
      ),
      body: AsyncStateView<WeekAttendance>(
        state: controller.state,
        onRetry: controller.load,
        emptyTitle: 'Belum ada sesi minggu ini',
        showFreshness: false,
        builder: (context, week) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecturer.name,
                    style: AppFonts.sansStyle(30, 700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minggu ini · ${formatShortDate(week.monday)}–'
                    '${formatShortDate(week.sunday)}',
                    style: AppFonts.sansStyle(18, 400, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            _SummaryCard(week: week),
            _SessionGrid(week: week),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Sesi batal dan mendatang di luar hitungan kehadiran. '
                '"Belum terkonfirmasi" berarti belum ada catatan absensi, '
                'bukan berarti dosen tidak hadir.',
                style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.sansStyle(20, 700, color: AppColors.ink)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.week});

  final WeekAttendance week;

  @override
  Widget build(BuildContext context) {
    final rate = week.rate;
    return _Card(
      title: 'Ringkasan kehadiran',
      child: Column(
        children: [
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _DonutPainter(
                  recorded: week.recorded,
                  unconfirmed: week.unconfirmed,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rate == null ? '–' : '${(rate * 100).round()}%',
                        key: const Key('attendance-rate'),
                        style: AppFonts.sansStyle(
                          44,
                          700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Tercatat',
                        style: AppFonts.sansStyle(
                          17,
                          400,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Dot(AppColors.accent, '${week.recorded} sesi tercatat'),
              _Dot(_red, '${week.unconfirmed} sesi belum terkonfirmasi'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          style: AppFonts.sansStyle(16, 400, color: AppColors.ink),
        ),
      ),
    ],
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.recorded, required this.unconfirmed});

  final int recorded;
  final int unconfirmed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 28.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    Paint ring(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = recorded + unconfirmed;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        ring(const Color(0xFFDDE3EE)),
      );
      return;
    }
    const start = -math.pi / 2;
    final red = 2 * math.pi * unconfirmed / total;
    canvas
      ..drawArc(
        rect,
        start + red,
        2 * math.pi - red,
        false,
        ring(AppColors.accent),
      )
      ..drawArc(rect, start, red, false, ring(_red));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.recorded != recorded || old.unconfirmed != unconfirmed;
}

/// Background, foreground, mark (icon or text) and label per state.
(Color, Color, Object, String) _markStyle(AttendanceMark m) => switch (m) {
  AttendanceMark.tercatat => (
    const Color(0xFFDCE8FF),
    AppColors.accent,
    Icons.check,
    'Tercatat',
  ),
  AttendanceMark.belumTerkonfirmasi => (
    const Color(0xFFFFE4E8),
    _red,
    Icons.question_mark,
    'Belum terkonfirmasi',
  ),
  AttendanceMark.batal => (
    const Color(0xFFDDE2EA),
    const Color(0xFF475569),
    '/',
    'Dibatalkan',
  ),
  AttendanceMark.belumBerlangsung => (
    const Color(0xFFEBEEF3),
    const Color(0xFF64748B),
    '–',
    'Belum berlangsung',
  ),
};

/// Numbered tiles, one per session this week (riwayat_dosen.png
/// "Pertemuan 1–14"). Tapping a tile opens the session.
class _SessionGrid extends StatelessWidget {
  const _SessionGrid({required this.week});

  final WeekAttendance week;

  @override
  Widget build(BuildContext context) {
    final n = week.sessions.length;
    return _Card(
      title: n == 0 ? 'Belum ada sesi minggu ini' : 'Sesi 1–$n',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap * 6) / 7;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < n; i++)
                    _Tile(
                      index: i + 1,
                      session: week.sessions[i],
                      mark: week.markOf(week.sessions[i]),
                      width: w,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [for (final m in AttendanceMark.values) _Legend(m)],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.index,
    required this.session,
    required this.mark,
    required this.width,
  });

  final int index;
  final Session session;
  final AttendanceMark mark;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, symbol, label) = _markStyle(mark);
    return Tooltip(
      message:
          '${session.courseName} · ${formatShortDate(session.start)} · $label',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('attendance-${session.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => openSessionDetail(context, session.id),
          child: SizedBox(
            width: width,
            height: width * 1.15,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text('$index', style: AppFonts.sansStyle(18, 700, color: fg)),
                  _Mark(symbol, color: fg, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.mark);

  final AttendanceMark mark;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, symbol, label) = _markStyle(mark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: _Mark(symbol, color: fg, size: 15),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppFonts.sansStyle(15, 400, color: AppColors.ink)),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.mark, {required this.color, required this.size});

  final Object mark;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => mark is IconData
      ? Icon(mark as IconData, color: color, size: size + 2)
      : Text('$mark', style: AppFonts.sansStyle(size, 600, color: color));
}
