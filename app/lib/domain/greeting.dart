import '../data/models/account.dart';

/// The part of an email before "@", used as the display/greeting name
/// (the register form has no name field).
String greetingNameFromEmail(String email) {
  final local = email.trim().split('@').first;
  return local.isEmpty ? email.trim() : local;
}

/// Greeting shown on Home: always the email's local part.
String greetingFor(Account account) => 'Halo, ${greetingNameFromEmail(account.email)}!';
