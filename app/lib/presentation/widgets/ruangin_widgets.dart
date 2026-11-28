import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/session.dart';
import '../../domain/session_status.dart';
import '../app_config_controller.dart';
import '../theme/app_theme.dart';

/// Building blocks for the screens in image/ui-ux/*.png.

const _cardColor = Color(0xFFF2F3F7);
const _avatarColor = Color(0xFFDCE8FF);

/// Grey card fill shared by the image/ui-ux cards.
const softCardColor = _cardColor;

/// Light blue used for selected chips, avatars and the nav highlight.
const softBlue = _avatarColor;

/// Status colours from detail_sesi1.png / detail_sesi_tercatat.png.
const statusRed = Color(0xFFDC2626);
const statusGreen = Color(0xFF15803D);

(Color, IconData) statusStyle(SessionStatus status) => switch (status) {
  SessionStatus.tercatat => (statusGreen, Icons.check_circle_outline),
  SessionStatus.belumTerkonfirmasi => (statusRed, Icons.schedule),
  SessionStatus.batal => (statusRed, Icons.cancel_outlined),
};

/// "BS" for "Dr. Budi Santoso" (titles and degrees skipped).
String initialsOf(String name) {
  final words = name
      .split(',')
      .first
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !w.endsWith('.'))
      .toList();
  final picked = words.length >= 2 ? [words.first, words[1]] : words;
  final s = picked.map((w) => w[0].toUpperCase()).join();
  return s.isEmpty && name.isNotEmpty ? name[0].toUpperCase() : s;
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.border,
  });

  final String name;
  final double size;
  final double? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColor,
        shape: BoxShape.circle,
        border: border == null
            ? null
            : Border.all(color: Colors.white, width: border!),
      ),
      child: Text(
        initialsOf(name),
        style: AppFonts.sansStyle(size * 0.36, 700, color: AppColors.accent),
      ),
    );
  }
}

/// Bold section heading ("Sesi hari ini", "Hasil cari").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.subtitle, this.padding});

  final String text;
  final String? subtitle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppFonts.sansStyle(28, 700, color: AppColors.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded grey search field from beranda.png / Hasil_Pencarian.png. With
/// [onTap] it is a read-only button that opens the search screen.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    this.controller,
    this.onTap,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.hint = 'Cari nama dosen',
    this.radius = 999,
  });

  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final String hint;

  /// 999 = pill (search screen); 14 = rounded box (Beranda).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: Color(0xFFE6E7EC)),
    );
    return TextField(
      controller: controller,
      readOnly: onTap != null,
      onTap: onTap,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: AppFonts.sansStyle(16, 400, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _cardColor,
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.close, color: AppColors.muted),
                onPressed: onClear,
              ),
        contentPadding: EdgeInsets.symmetric(vertical: radius < 100 ? 16 : 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

/// Status as a small pill (beranda.png). Texts follow the PRD rule: no
/// attendance record is "Belum terkonfirmasi", never "Batal".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text) = switch (session.status) {
      SessionStatus.tercatat => (
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
        'Tercatat',
      ),
      SessionStatus.belumTerkonfirmasi => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Belum terkonfirmasi',
      ),
      SessionStatus.batal => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        'Batal',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppFonts.sansStyle(13, 500, color: fg)),
    );
  }
}

/// Status as icon + text (Profil_Dosen.png and Beranda cards). [short]
/// drops the sync time ("Tercatat" instead of "Tercatat · Sinkron ...").
class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.session,
    this.short = false,
    this.size = 14,
    this.weight = 500,
  });

  final Session session;
  final bool short;
  final double size;
  final int weight;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = statusStyle(session.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size + 6, color: color),
        SizedBox(width: size * 0.5),
        Flexible(
          child: Text(
            short ? session.statusShortLabel : session.statusLabel,
            style: AppFonts.sansStyle(size, weight, color: color),
          ),
        ),
      ],
    );
  }
}

/// Beranda "Sesi hari ini" card (beranda_tanpa_peringatan.png): icon box |
/// course + lecturer, then time · room, then the status line.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.highlight = false,
    this.trailingBadge,
  });

  final Session session;
  final VoidCallback onTap;

  /// The next upcoming session gets an accent outline.
  final bool highlight;
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highlight
              ? const BorderSide(color: AppColors.accent, width: 1.4)
              : const BorderSide(color: Color(0xFFE4E6EE)),
        ),
        child: InkWell(
          key: Key('session-${s.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E7EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.layers_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                      const VerticalDivider(
                        width: 28,
                        thickness: 1,
                        color: Color(0xFFD5D7DE),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.courseName,
                              style:
                                  AppFonts.sansStyle(
                                    19,
                                    600,
                                    color: AppColors.ink,
                                  ).copyWith(
                                    decoration: s.isCancelled
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.lecturer?.name ?? 'Prodi ${s.prodi}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.sansStyle(
                                15,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${formatTimeRange(s.start, s.end)} · ${s.place}',
                        style: AppFonts.sansStyle(
                          15,
                          400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: StatusLine(
                          session: s,
                          short: true,
                          size: 16,
                          weight: 600,
                        ),
                      ),
                      if (trailingBadge != null) ...[
                        const SizedBox(width: 8),
                        trailingBadge!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lecturer profile timeline row (profil.png).
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.session,
    required this.onTap,
    this.isFollowed = false,
    this.showDate = false,
  });

  final Session session;
  final VoidCallback onTap;
  final bool isFollowed;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return InkWell(
      key: Key('session-${s.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(s.start),
                    style: AppFonts.sansStyle(18, 500, color: AppColors.ink),
                  ),
                  Text(
                    formatTime(s.end),
                    style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.courseName,
                    style: AppFonts.sansStyle(17, 700, color: AppColors.ink)
                        .copyWith(
                          decoration: s.isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (showDate) formatShortDate(s.start),
                      s.place,
                      'Prodi ${s.prodi}',
                    ].join(' · '),
                    style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  StatusLine(session: s),
                ],
              ),
            ),
            if (isFollowed)
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 4),
                child: Icon(
                  Icons.notifications_active,
                  size: 20,
                  color: AppColors.accent,
                  semanticLabel: 'Diikuti',
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey rounded list card (Hasil_Pencarian.png rows, report queue items).
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "Simulasi" chip (beranda, detail_sesi, notifikasi designs). Shown only
/// while the server reports that all schedules and attendance are synthetic
/// / simulated (`GET /app-config` simulatedData, PRD §10 "tandai data
/// sintetis"). [text] lets a screen say "Data simulasi" in running text.
class SimulatedChip extends StatelessWidget {
  const SimulatedChip({super.key, this.plain = false, this.text = 'Simulasi'});

  /// Italic text without the grey pill (notification footer).
  final bool plain;
  final String text;

  static const tooltip =
      'Data simulasi: jadwal dan catatan absensi di Ruangin saat ini '
      'adalah data contoh, bukan data kampus asli.';

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppConfigController>().simulatedData) {
      return const SizedBox.shrink();
    }
    final label = plain
        ? Text(
            text,
            style: AppFonts.sansStyle(
              14,
              400,
              color: AppColors.ink,
            ).copyWith(fontStyle: FontStyle.italic),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EAEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: AppFonts.sansStyle(14, 500, color: AppColors.ink),
            ),
          );
    return Tooltip(
      key: const Key('simulated-chip'),
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: label,
    );
  }
}
