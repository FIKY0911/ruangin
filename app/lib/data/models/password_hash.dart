import 'package:flutter/foundation.dart';

import 'account.dart';

/// Stored password verifier. The plain-text password is never persisted.
@immutable
class PasswordHash {
  const PasswordHash({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Base64 random salt.
  final String salt;

  /// Base64 PBKDF2-HMAC-SHA256 derived key.
  final String hash;
  final int iterations;

  factory PasswordHash.fromJson(Map<String, dynamic> json) => PasswordHash(
        salt: json['salt'] as String,
        hash: json['hash'] as String,
        iterations: json['iterations'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'salt': salt, 'hash': hash, 'iterations': iterations};
}

/// An account together with its password verifier.
@immutable
class AuthRecord {
  const AuthRecord(this.account, this.password);

  final Account account;
  final PasswordHash password;
}
