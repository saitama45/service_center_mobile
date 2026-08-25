import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/utils/totp_util.dart';

void main() {
  // RFC 6238 Appendix B uses the ASCII secret "12345678901234567890" for the
  // SHA-1 vectors. Its base32 form is what an authenticator app would be given.
  final rfcSecretBytes = utf8.encode('12345678901234567890');
  const rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  DateTime atUnix(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  group('Base32', () {
    test('encodes the RFC 6238 test secret to the canonical key', () {
      expect(Base32.encode(rfcSecretBytes), rfcSecretBase32);
    });

    test('round-trips arbitrary bytes', () {
      final bytes = List<int>.generate(37, (i) => (i * 7 + 3) % 256);
      expect(Base32.decode(Base32.encode(bytes)), bytes);
    });

    test('encodes without padding', () {
      // 1 byte is 8 bits -> 2 base32 chars, and no trailing "=".
      expect(Base32.encode([0xFF]), '74');
      expect(Base32.encode([0xFF]).contains('='), isFalse);
    });

    test('tolerates the spaces, dashes and padding people retype', () {
      final canonical = Base32.decode(rfcSecretBase32);
      expect(
          Base32.decode('gezd gnbv gy3t qojq gezd gnbv gy3t qojq'), canonical);
      expect(
          Base32.decode('GEZD-GNBV-GY3T-QOJQ-GEZD-GNBV-GY3T-QOJQ'), canonical);
      expect(Base32.decode('MFRGG==='), Base32.decode('MFRGG'));
    });

    test('rejects characters outside the alphabet', () {
      // 0, 1 and 8 are deliberately absent from RFC 4648 base32.
      expect(() => Base32.decode('ABC0'), throwsFormatException);
      expect(() => Base32.decode('ABC1'), throwsFormatException);
      expect(() => Base32.decode('ABC8'), throwsFormatException);
    });

    test('empty input round-trips to empty output', () {
      expect(Base32.encode([]), '');
      expect(Base32.decode(''), isEmpty);
    });
  });

  group('TotpUtil.codeFor - RFC 6238 SHA-1 vectors', () {
    // The RFC publishes 8-digit codes; a 6-digit TOTP is the low 6 digits of
    // the same dynamic truncation, so these are the RFC values truncated.
    const vectors = <int, String>{
      59: '287082',
      1111111109: '081804',
      1111111111: '050471',
      1234567890: '005924',
      2000000000: '279037',
      20000000000: '353130',
    };

    vectors.forEach((unixSeconds, expected) {
      test('T=$unixSeconds produces $expected', () {
        expect(
          TotpUtil.codeFor(rfcSecretBase32, at: atUnix(unixSeconds)),
          expected,
        );
      });
    });

    test('always returns exactly six digits, zero-padded', () {
      final secret = TotpUtil.generateSecret();
      for (var step = 0; step < 200; step++) {
        final code = TotpUtil.codeFor(secret, at: atUnix(step * 30));
        expect(code, matches(RegExp(r'^\d{6}$')));
      }
    });

    test('is stable across a 30-second step and changes at the boundary', () {
      final secret = TotpUtil.generateSecret();
      final inStep = TotpUtil.codeFor(secret, at: atUnix(1700000010));
      expect(TotpUtil.codeFor(secret, at: atUnix(1700000029)), inStep);
      // 1700000010 sits in step 56666667; 1700000040 is the next step.
      expect(TotpUtil.codeFor(secret, at: atUnix(1700000040)), isNot(inStep));
    });
  });

  group('TotpUtil.verify', () {
    const now = 1234567890; // an RFC vector instant

    test('accepts the current code', () {
      expect(
        TotpUtil.verify(rfcSecretBase32, '005924', at: atUnix(now)),
        isTrue,
      );
    });

    test('accepts one step of drift in either direction', () {
      final previous = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now - 30));
      final next = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now + 30));
      expect(
          TotpUtil.verify(rfcSecretBase32, previous, at: atUnix(now)), isTrue);
      expect(TotpUtil.verify(rfcSecretBase32, next, at: atUnix(now)), isTrue);
    });

    test('rejects two steps of drift', () {
      final stale = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now - 60));
      final future = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now + 60));
      expect(TotpUtil.verify(rfcSecretBase32, stale, at: atUnix(now)), isFalse);
      expect(
          TotpUtil.verify(rfcSecretBase32, future, at: atUnix(now)), isFalse);
    });

    test('honours a widened window', () {
      final stale = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now - 60));
      expect(
        TotpUtil.verify(rfcSecretBase32, stale, at: atUnix(now), window: 2),
        isTrue,
      );
    });

    test('rejects a window of zero outside the exact step', () {
      final previous = TotpUtil.codeFor(rfcSecretBase32, at: atUnix(now - 30));
      expect(
        TotpUtil.verify(rfcSecretBase32, previous, at: atUnix(now), window: 0),
        isFalse,
      );
      expect(
        TotpUtil.verify(rfcSecretBase32, '005924', at: atUnix(now), window: 0),
        isTrue,
      );
    });

    test('rejects a wrong code', () {
      expect(
        TotpUtil.verify(rfcSecretBase32, '000000', at: atUnix(now)),
        isFalse,
      );
    });

    test('rejects codes that are not six digits', () {
      for (final bad in ['', '1', '12345', '1234567', 'abcdef', '00592']) {
        expect(TotpUtil.verify(rfcSecretBase32, bad, at: atUnix(now)), isFalse,
            reason: 'should reject "$bad"');
      }
    });

    test('strips separators the digit boxes may leave behind', () {
      expect(
        TotpUtil.verify(rfcSecretBase32, '005 924', at: atUnix(now)),
        isTrue,
      );
    });

    test('returns false instead of throwing on a corrupt secret', () {
      expect(TotpUtil.verify('not-valid-base32!!', '005924'), isFalse);
      expect(TotpUtil.verify('', '005924'), isFalse);
    });

    test('a code from another secret does not verify', () {
      final other = TotpUtil.generateSecret();
      final otherCode = TotpUtil.codeFor(other, at: atUnix(now));
      expect(
        TotpUtil.verify(rfcSecretBase32, otherCode, at: atUnix(now)),
        isFalse,
      );
    });
  });

  group('TotpUtil.generateSecret', () {
    test('produces a 32-character base32 key for 160 bits', () {
      final secret = TotpUtil.generateSecret();
      expect(secret.length, 32);
      expect(secret, matches(RegExp(r'^[A-Z2-7]+$')));
      expect(Base32.decode(secret).length, 20);
    });

    test('does not repeat', () {
      final secrets = List.generate(50, (_) => TotpUtil.generateSecret());
      expect(secrets.toSet().length, 50);
    });

    test('honours a custom byte length', () {
      expect(Base32.decode(TotpUtil.generateSecret(byteLength: 10)).length, 10);
    });
  });

  group('TotpUtil.secondsRemaining', () {
    test('counts down to the step boundary', () {
      // 1700000010 is an exact step boundary, so the countdown restarts there.
      expect(TotpUtil.secondsRemaining(at: atUnix(1700000010)), 30);
      expect(TotpUtil.secondsRemaining(at: atUnix(1700000011)), 29);
      expect(TotpUtil.secondsRemaining(at: atUnix(1700000039)), 1);
      expect(TotpUtil.secondsRemaining(at: atUnix(1700000040)), 30);
    });
  });

  group('TotpUtil.provisioningUri', () {
    test('builds a scannable otpauth URI with the expected parameters', () {
      final uri = Uri.parse(TotpUtil.provisioningUri(
        base32Secret: rfcSecretBase32,
        account: 'member@example.com',
        issuer: 'TAS Service Center',
      ));

      expect(uri.scheme, 'otpauth');
      expect(uri.host, 'totp');
      // pathSegments decodes; the raw path keeps the percent-encoding that
      // the Key Uri Format spec requires.
      expect(uri.pathSegments.single, 'TAS Service Center:member@example.com');
      expect(uri.path, '/TAS%20Service%20Center%3Amember%40example.com');
      expect(uri.queryParameters['secret'], rfcSecretBase32);
      expect(uri.queryParameters['issuer'], 'TAS Service Center');
      expect(uri.queryParameters['algorithm'], 'SHA1');
      expect(uri.queryParameters['digits'], '6');
      expect(uri.queryParameters['period'], '30');
    });

    test('percent-encodes characters that would break the URI', () {
      final raw = TotpUtil.provisioningUri(
        base32Secret: rfcSecretBase32,
        account: 'a b&c@example.com',
        issuer: 'TAS & Co',
      );
      // The raw string must not contain a bare space or a stray separator.
      expect(raw.contains(' '), isFalse);
      final uri = Uri.parse(raw);
      expect(uri.queryParameters['issuer'], 'TAS & Co');
      expect(uri.pathSegments.single, 'TAS & Co:a b&c@example.com');
    });
  });

  group('TotpUtil.formatSecretForDisplay', () {
    test('groups into four-character blocks', () {
      expect(
        TotpUtil.formatSecretForDisplay(rfcSecretBase32),
        'GEZD GNBV GY3T QOJQ GEZD GNBV GY3T QOJQ',
      );
    });

    test('leaves a short trailing block intact', () {
      expect(TotpUtil.formatSecretForDisplay('ABCDEF'), 'ABCD EF');
      expect(TotpUtil.formatSecretForDisplay(''), '');
    });
  });
}
