import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/utils/bcrypt_util.dart';

void main() {
  group('BcryptUtil', () {
    test('hash produces a non-plaintext output', () {
      const password = 'TestPass@1';
      final hash = BcryptUtil.hash(password);
      expect(hash, isNot(equals(password)));
      expect(hash.startsWith('\$2'), isTrue); // bcrypt prefix
    });

    test('verify returns true for matching password', () {
      const password = 'TestPass@1';
      final hash = BcryptUtil.hash(password);
      expect(BcryptUtil.verify(password, hash), isTrue);
    });

    test('verify returns false for wrong password', () {
      const password = 'TestPass@1';
      final hash = BcryptUtil.hash(password);
      expect(BcryptUtil.verify('WrongPass@9', hash), isFalse);
    });

    test('isStrong rejects short passwords', () {
      expect(BcryptUtil.isStrong('Ab1!'), isFalse);
    });

    test('isStrong rejects passwords without uppercase', () {
      expect(BcryptUtil.isStrong('testpass@1'), isFalse);
    });

    test('isStrong rejects passwords without digits', () {
      expect(BcryptUtil.isStrong('TestPass@!'), isFalse);
    });

    test('isStrong rejects passwords without special char', () {
      expect(BcryptUtil.isStrong('TestPass123'), isFalse);
    });

    test('isStrong accepts valid strong passwords', () {
      expect(BcryptUtil.isStrong('Admin@2024!'), isTrue);
    });
  });
}
