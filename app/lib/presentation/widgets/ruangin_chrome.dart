import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../theme/app_theme.dart';
import 'ruangin_widgets.dart';

/// Page chrome from the second batch of image/ui-ux designs: the blue wave
/// at the bottom of Beranda / search / notifications, the floating pill
/// navigation bar and the logo header.

/// Blue wave filling the bottom of the page (Beranda_peringatan_dini.png).
/// Put it as the first child of a [Stack] so content scrolls over it.
class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key, this.heightFactor = 0.25});

  /// Share of the available height the wave covers.
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            widthFactor: 1,
            child: const CustomPaint(painter: _WavePainter()),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.08)
      ..cubicTo(w * 0.22, -h * 0.06, w * 0.38, h * 0.06, w * 0.52, h * 0.30)
      ..cubicTo(w * 0.64, h * 0.48, w * 0.82, h * 0.40, w, h * 0.16)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1463F3), AppColors.accent],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}

class NavItem {
  const NavItem(this.key, this.icon, this.selectedIcon, this.label);

  final Key key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Height the floating nav bar takes from the bottom of the screen (without
/// the system inset). Pages under it pad their scroll views by this much.
const navBarClearance = 96.0;

/// Floating, translucent pill with Beranda · Jadwal · Laporan · Profil
/// (Beranda_peringatan_dini.png, Profil_Dosen.png).
class RuanginNavBar extends StatelessWidget {
  const RuanginNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(40, 0, 40, 14 + bottom),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFD5E2FB), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        key: item.key,
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? softBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 26,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: AppFonts.sansStyle(
                  13,
                  selected ? 600 : 500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ruangin" logo used in page headers.
class RuanginLogo extends StatelessWidget {
  const RuanginLogo({super.key, this.height = 34});

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    BrandAssets.logoCropped,
    height: height,
    semanticLabel: 'Ruangin',
  );
}

/// Illustration + title + message (Tidak_ada_Hasil.png, Hasil_cari1.png).
class IllustrationMessage extends StatelessWidget {
  const IllustrationMessage({
    super.key,
    required this.image,
    this.title,
    required this.message,
    this.imageHeight = 220,
  });

  final String image;
  final String? title;
  final String message;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(image, height: imageHeight, fit: BoxFit.contain),
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: AppFonts.sansStyle(26, 700, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(
              title == null ? 19 : 17,
              400,
              color: title == null ? AppColors.ink : const Color(0xFF4B4F6B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large blue button from detail_sesi1.png ("Ikuti", "Kirim laporan").
ButtonStyle primaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: AppColors.accent,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: AppFonts.sansStyle(19, 600),
);
