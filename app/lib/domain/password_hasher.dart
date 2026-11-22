import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../data/models/password_hash.dart';

/// Port for hashing/verifying passwords so storage never sees plain text.
abstract interface class PasswordHasher {
  PasswordHash hash(String password);
  bool verify(String password, PasswordHash stored);
}

/// PBKDF2-HMAC-SHA256 with a random 16-byte salt per account.
///
/// 10 000 iterations is a deliberate trade-off for the offline demo (fast on
/// low-end Android, seed hashes precomputed). When a real backend is added,
/// hash server-side and raise this to the current OWASP recommendation
/// (~600 000 iterations for PBKDF2-HMAC-SHA256); stored hashes keep their own
/// `iterations`, so old records still verify.
class Pbkdf2PasswordHasher implements PasswordHasher {
  Pbkdf2PasswordHasher({this.iterations = 10000, Random? random})
      : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;

  @override
  PasswordHash hash(String password) {
    final salt = Uint8List.fromList(
        List<int>.generate(16, (_) => _random.nextInt(256)));
    return PasswordHash(
      salt: base64Encode(salt),
      hash: base64Encode(pbkdf2Sha256(utf8.encode(password), salt, iterations)),
      iterations: iterations,
    );
  }

  @override
  bool verify(String password, PasswordHash stored) {
    final derived = pbkdf2Sha256(
        utf8.encode(password), base64Decode(stored.salt), stored.iterations);
    return _constantTimeEquals(derived, base64Decode(stored.hash));
  }
}

/// Single-block (32-byte) PBKDF2-HMAC-SHA256 (RFC 8018).
Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
