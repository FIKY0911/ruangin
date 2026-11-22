import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../theme/app_theme.dart';

/// Message for design elements whose feature has no backend yet.
const notAvailableInDemo = 'Belum tersedia di demo';

void showNotAvailable(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      key: Key('not-available'),
      content: Text(notAvailableInDemo),
    ));
}

/// Register/Login page frame: grey app bar with back + centred title, then a
/// centred "R" icon and heading.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.heading,
    required this.children,
    this.topGap = 56,
  });

  final String title;
  final String heading;
  final List<Widget> children;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            SizedBox(height: topGap),
            Center(child: Image.asset(BrandAssets.icon, height: 48)),
            const SizedBox(height: 10),
            Text(heading,
                textAlign: TextAlign.center,
                style: AppFonts.sansStyle(28, 600, color: AppColors.ink)),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Bold label above an input, with an optional trailing widget (e.g. link).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppFonts.sansStyle(16, 600))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Email input with the blue pencil icon from the design.
class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.onChanged,
    this.controller,
    this.errorText,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      style: AppFonts.sansStyle(16, 400),
      decoration: InputDecoration(
        hintText: 'nama@email.com',
        errorText: errorText,
        suffixIcon: const Icon(Icons.edit_outlined, color: AppColors.accent),
      ),
    );
  }
}

/// Password input with an eye toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.onChanged,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscure,
      obscuringCharacter: '●',
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      style: AppFonts.sansStyle(16, 400),
      decoration: InputDecoration(
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Full-width black primary button with a loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              key: Key('submit-loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
          : Text(label),
    );
  }
}

enum SocialProvider { apple, google }

/// Outlined "Sign in/up with Apple/Google" button.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.provider,
    required this.label,
    required this.onPressed,
  });

  final SocialProvider provider;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            switch (provider) {
              SocialProvider.apple =>
                const Icon(Icons.apple, size: 30, color: Colors.black),
              SocialProvider.google => const GoogleLogo(size: 24),
            },
            const SizedBox(width: 14),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Prompt? Link" line, e.g. "Already have an account? Sign in".
class InlineLink extends StatelessWidget {
  const InlineLink({
    super.key,
    required this.prompt,
    required this.link,
    required this.onTap,
  });

  final String prompt;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '$prompt ',
                style: AppFonts.sansStyle(17, 500, color: AppColors.ink)),
            TextSpan(
                text: link,
                style: AppFonts.sansStyle(17, 600, color: AppColors.accent)),
          ]),
        ),
      ),
    );
  }
}

/// Grey legal footer with underlined Terms / Privacy links.
class TermsFooter extends StatefulWidget {
  const TermsFooter({super.key, required this.onTermsTap, required this.onPrivacyTap});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<TermsFooter> createState() => _TermsFooterState();
}

class _TermsFooterState extends State<TermsFooter> {
  late final _terms = TapGestureRecognizer()..onTap = widget.onTermsTap;
  late final _privacy = TapGestureRecognizer()..onTap = widget.onPrivacyTap;

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppFonts.sansStyle(14.5, 400, color: AppColors.muted)
        .copyWith(height: 1.5);
    final link = base.copyWith(decoration: TextDecoration.underline);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text.rich(
        TextSpan(style: base, children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms of Service', style: link, recognizer: _terms),
          const TextSpan(text: ' and have read our '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ]),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('form-error'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppFonts.sansStyle(15, 500, color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Four-colour Google "G" mark drawn with arcs (no image asset available).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double deg(double d) => d * math.pi / 180;
    // Angles: 0° = 3 o'clock, clockwise.
    canvas.drawArc(rect, deg(-40), deg(-100), false, p(_red));
    canvas.drawArc(rect, deg(-140), deg(-90), false, p(_yellow));
    canvas.drawArc(rect, deg(130), deg(-90), false, p(_green));
    canvas.drawArc(rect, deg(40), deg(-40), false, p(_blue));
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5 - stroke * 0.05, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
