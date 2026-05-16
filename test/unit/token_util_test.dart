import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/utils/token_util.dart';

void main() {
  group('TokenUtil', () {
    test('generateSecureToken produces a non-empty base64url string', () {
      final token = TokenUtil.generateSecureToken();
      expect(token.isNotEmpty, isTrue);
      expect(token.length, greaterThan(30));
    });

    test('two generated tokens are unique', () {
      final t1 = TokenUtil.generateSecureToken();
      final t2 = TokenUtil.generateSecureToken();
      expect(t1, isNot(equals(t2)));
    });

    test('hashToken produces a 64-char hex SHA-256 hash', () {
      final token = TokenUtil.generateSecureToken();
      final hash = TokenUtil.hashToken(token);
      expect(hash.length, equals(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('hashToken is deterministic for the same input', () {
      const raw = 'test_token_value';
      expect(TokenUtil.hashToken(raw), equals(TokenUtil.hashToken(raw)));
    });

    test('hashToken differs for different inputs', () {
      expect(
        TokenUtil.hashToken('token_a'),
        isNot(equals(TokenUtil.hashToken('token_b'))),
      );
    });

    test('raw token is never equal to its hash', () {
      final token = TokenUtil.generateSecureToken();
      expect(TokenUtil.hashToken(token), isNot(equals(token)));
    });
  });
}
