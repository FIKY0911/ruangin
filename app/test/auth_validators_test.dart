import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/domain/auth_service.dart';
import 'package:ruangin/domain/auth_validators.dart';
import 'package:ruangin/domain/greeting.dart';

void main() {
  group('AuthValidators', () {
    test('email format', () {
      expect(AuthValidators.email(''), 'Email wajib diisi.');
      for (final bad in ['nadia', 'nadia@', 'nadia@kampus', '@x.id', 'a b@x.id']) {
        expect(AuthValidators.email(bad), 'Format email tidak valid.', reason: bad);
      }
      expect(AuthValidators.email(' Nadia@Kampus.ac.id '), isNull);
    });

    test('password minimum length', () {
      expect(AuthValidators.password(''), 'Password wajib diisi.');
      expect(AuthValidators.password('1234567'), 'Password minimal 8 karakter.');
      expect(AuthValidators.password('12345678'), isNull);
    });

    test('confirmation must match', () {
      expect(AuthValidators.confirmPassword('abcdefgh', ''), isNotNull);
      expect(AuthValidators.confirmPassword('abcdefgh', 'abcdefgX'),
          'Konfirmasi password tidak sama.');
      expect(AuthValidators.confirmPassword('abcdefgh', 'abcdefgh'), isNull);
    });

    test('normalizeEmail trims and lower-cases', () {
      expect(AuthValidators.normalizeEmail('  Nadia@Demo.ID '), 'nadia@demo.id');
    });
  });

  test('greeting uses the email part before @', () {
    expect(greetingNameFromEmail(' andikacatvr@gmail.com '), 'andikacatvr');
    expect(greetingNameFromEmail('noat'), 'noat');
  });

  test('validateRegister collects every field error', () {
    final errors = AuthService.validateRegister(const RegisterInput(
        email: 'x', password: '123', confirmPassword: '321'));
    expect(errors.keys, unorderedEquals(AuthField.values));
  });
}
