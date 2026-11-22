import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

/// Navigation between the auth screens. Welcome stays at the bottom of the
/// stack; Register and Login replace each other.
Future<void> openRegister(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => const RegisterScreen());
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

Future<void> openLogin(
  BuildContext context, {
  bool replace = false,
  String initialEmail = '',
  bool justRegistered = false,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) =>
        LoginScreen(initialEmail: initialEmail, justRegistered: justRegistered),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

/// After sign-in the auth gate shows Home; drop the auth routes above it.
void closeAuthFlow(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);
