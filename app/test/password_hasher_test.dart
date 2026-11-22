import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/data/fixtures/seed_data.dart';
import 'package:ruangin/domain/password_hasher.dart';

void main() {
  final hasher = Pbkdf2PasswordHasher(iterations: 1000);

  test('hash never contains the plain password and verifies correctly', () {
    final h = hasher.hash('rahasia123');
    expect(h.hash, isNot(contains('rahasia123')));
    expect(hasher.verify('rahasia123', h), isTrue);
    expect(hasher.verify('rahasia124', h), isFalse);
  });

  test('random salt: same password gives different hashes', () {
    final a = hasher.hash('rahasia123'), b = hasher.hash('rahasia123');
    expect(a.salt, isNot(b.salt));
    expect(a.hash, isNot(b.hash));
  });

  test('matches reference PBKDF2 (seed demo hashes made with Python hashlib)', () {
    final seed = SeedData.parse(const SystemClock().now());
    for (final entry in seed.credentials.entries) {
      expect(hasher.verify('ruangin123', entry.value), isTrue, reason: entry.key);
      expect(hasher.verify('salah', entry.value), isFalse);
    }
  });
}
