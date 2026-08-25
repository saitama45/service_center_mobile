import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/utils/totp_util.dart';
import 'package:bms/data/datasources/local/totp_secret_store.dart';
import 'package:bms/data/datasources/remote/otp_remote_datasource.dart';
import 'package:bms/presentation/providers/auth_flow_provider.dart';

/// In-memory stand-in for the keystore-backed store — overrides every method
/// so no platform channel is touched.
class _FakeSecretStore implements TotpSecretStore {
  final Map<String, String> _secrets = {};
  final Map<String, DateTime> _enrolledAt = {};

  @override
  Future<String?> readSecret(String userId) async => _secrets[userId];

  @override
  Future<bool> isEnrolled(String userId) async => _secrets.containsKey(userId);

  @override
  Future<void> saveSecret(String userId, String base32Secret) async {
    _secrets[userId] = base32Secret;
    _enrolledAt[userId] = DateTime.now();
  }

  @override
  Future<DateTime?> enrolledAt(String userId) async => _enrolledAt[userId];

  @override
  Future<void> deleteSecret(String userId) async {
    _secrets.remove(userId);
    _enrolledAt.remove(userId);
  }
}

/// Scripted stand-in for the server round trip — the test queues the
/// outcome each call should return instead of hitting the network.
class _FakeOtpRemote implements OtpRemoteDatasource {
  final List<OtpSendOutcome> sendQueue = [];
  final List<OtpVerifyOutcome> verifyQueue = [];
  int sendCalls = 0;
  int verifyCalls = 0;
  String? lastVerifiedCode;

  @override
  Future<OtpSendOutcome> send() async {
    sendCalls++;
    return sendQueue.isNotEmpty ? sendQueue.removeAt(0) : sendQueue.last;
  }

  @override
  Future<OtpVerifyOutcome> verify(String code) async {
    verifyCalls++;
    lastVerifiedCode = code;
    return verifyQueue.isNotEmpty ? verifyQueue.removeAt(0) : verifyQueue.last;
  }
}

void main() {
  const userId = 'member-1';

  group('OtpController — online, no authenticator enrolled', () {
    test('issue() requests an emailed code and readies the email channel',
        () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: 'j***@example.com',
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ));
      final controller = OtpController(remote, _FakeSecretStore());

      final outcome =
          await controller.issue(userId: userId, offlineLogin: false);

      expect(outcome, OtpIssueOutcome.ready);
      expect(controller.state.channel, OtpChannel.email);
      expect(controller.state.destination, 'j***@example.com');
      expect(controller.state.expiresAt, isNotNull);
      expect(remote.sendCalls, 1);
    });

    test('verify() accepts a code the server confirms', () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: 'j***@example.com',
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ))
        ..verifyQueue.add(const OtpVerifyAccepted());
      final controller = OtpController(remote, _FakeSecretStore());
      await controller.issue(userId: userId, offlineLogin: false);

      final error = await controller.verify('123456');

      expect(error, isNull);
      expect(remote.lastVerifiedCode, '123456');
    });

    test('verify() surfaces attempts remaining on a wrong code', () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: null,
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ))
        ..verifyQueue.add(const OtpVerifyRejected(
          message: 'Incorrect code.',
          attemptsRemaining: 3,
        ));
      final controller = OtpController(remote, _FakeSecretStore());
      await controller.issue(userId: userId, offlineLogin: false);

      final error = await controller.verify('000000');

      expect(error, contains('3 attempts left'));
      expect(controller.state.attemptsRemaining, 3);
    });

    test('verify() rejects locally once the emailed code has expired',
        () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: null,
          validity: Duration(seconds: -1), // already expired
          resendAfter: Duration(seconds: 30),
        ));
      final controller = OtpController(remote, _FakeSecretStore());
      await controller.issue(userId: userId, offlineLogin: false);

      final error = await controller.verify('123456');

      expect(error, contains('expired'));
      // Expiry is caught before a wasted round trip to the server.
      expect(remote.verifyCalls, 0);
    });

    test('an unreachable server with no authenticator blocks the step',
        () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendUnreachable('No connection.'));
      final controller = OtpController(remote, _FakeSecretStore());

      final outcome =
          await controller.issue(userId: userId, offlineLogin: false);

      expect(outcome, OtpIssueOutcome.blocked);
      expect(controller.state.blocker, 'No connection.');
    });

    test('a server with no OTP routes deployed skips the step by default',
        () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendUnsupported('404 from /api/otp/send'));
      final controller = OtpController(remote, _FakeSecretStore());

      final outcome =
          await controller.issue(userId: userId, offlineLogin: false);

      expect(outcome, OtpIssueOutcome.skipped);
      expect(controller.state.channel, isNull);
    });
  });

  group('OtpController — online, authenticator enrolled (the default)', () {
    test('issue() goes straight to the authenticator channel, no email attempt',
        () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final remote = _FakeOtpRemote();
      final controller = OtpController(remote, store);

      final outcome =
          await controller.issue(userId: userId, offlineLogin: false);

      expect(outcome, OtpIssueOutcome.ready);
      expect(controller.state.channel, OtpChannel.authenticator);
      expect(controller.state.hasAuthenticator, isTrue);
      expect(controller.state.degraded, isNull); // not a fallback — the default
      expect(remote.sendCalls, 0);

      final code = TotpUtil.codeFor(secret);
      expect(await controller.verify(code), isNull);
    });

    test('canSwitchToEmail is true (online, on the authenticator channel)',
        () async {
      final store = _FakeSecretStore();
      await store.saveSecret(userId, TotpUtil.generateSecret());
      final controller = OtpController(_FakeOtpRemote(), store);
      await controller.issue(userId: userId, offlineLogin: false);

      expect(controller.state.canSwitchToEmail, isTrue);
      expect(controller.state.canSwitchToAuthenticator, isFalse);
    });

    test('switchToEmail() requests a code and moves to the email channel',
        () async {
      final store = _FakeSecretStore();
      await store.saveSecret(userId, TotpUtil.generateSecret());
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: 'j***@example.com',
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ));
      final controller = OtpController(remote, store);
      await controller.issue(userId: userId, offlineLogin: false);

      await controller.switchToEmail();

      expect(controller.state.channel, OtpChannel.email);
      expect(controller.state.destination, 'j***@example.com');
      expect(remote.sendCalls, 1);
      // Can still switch back — the secret is still enrolled.
      expect(controller.state.canSwitchToAuthenticator, isTrue);
    });

    test('switchToEmail() falling back to authenticator carries hasAuthenticator forward',
        () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendUnreachable('No connection.'));
      final controller = OtpController(remote, store);
      await controller.issue(userId: userId, offlineLogin: false);

      await controller.switchToEmail();

      // Email failed, so it silently dropped back to the authenticator —
      // this time as a genuine fallback, so `degraded` is set.
      expect(controller.state.channel, OtpChannel.authenticator);
      expect(controller.state.degraded, isNotNull);
      final code = TotpUtil.codeFor(secret);
      expect(await controller.verify(code), isNull);
    });

    test('switchToAuthenticator() after switching to email needs no round trip',
        () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: 'j***@example.com',
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ));
      final controller = OtpController(remote, store);
      await controller.issue(userId: userId, offlineLogin: false);
      await controller.switchToEmail();
      final sendCallsAfterSwitch = remote.sendCalls;

      controller.switchToAuthenticator();

      expect(controller.state.channel, OtpChannel.authenticator);
      expect(remote.sendCalls, sendCallsAfterSwitch); // no extra network call
      final code = TotpUtil.codeFor(secret);
      expect(await controller.verify(code), isNull);
    });

    test('switchToEmail() is a no-op while already on the email channel',
        () async {
      final store = _FakeSecretStore();
      await store.saveSecret(userId, TotpUtil.generateSecret());
      final remote = _FakeOtpRemote()
        ..sendQueue.add(const OtpSendAccepted(
          destination: 'j***@example.com',
          validity: Duration(minutes: 5),
          resendAfter: Duration(seconds: 30),
        ));
      final controller = OtpController(remote, store);
      await controller.issue(userId: userId, offlineLogin: false);
      await controller.switchToEmail();
      final sendCallsAfterFirstSwitch = remote.sendCalls;

      await controller.switchToEmail();

      expect(remote.sendCalls, sendCallsAfterFirstSwitch);
    });
  });

  group('OtpController — offline login', () {
    test('with an enrolled authenticator, verifies the current TOTP code',
        () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final controller = OtpController(_FakeOtpRemote(), store);

      final outcome =
          await controller.issue(userId: userId, offlineLogin: true);

      expect(outcome, OtpIssueOutcome.ready);
      expect(controller.state.channel, OtpChannel.authenticator);
      // No connection means no email fallback either, unlike the online case.
      expect(controller.state.canSwitchToEmail, isFalse);

      final code = TotpUtil.codeFor(secret);
      expect(await controller.verify(code), isNull);
    });

    test('rejects a wrong TOTP code and counts the attempt down', () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final controller = OtpController(_FakeOtpRemote(), store);
      await controller.issue(userId: userId, offlineLogin: true);

      final error = await controller.verify('000000');

      expect(error, contains('attempt'));
      expect(controller.state.attemptsRemaining,
          OtpPolicy.maxAuthenticatorAttempts - 1);
    });

    test('blocks the step after exhausting authenticator attempts', () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final controller = OtpController(_FakeOtpRemote(), store);
      await controller.issue(userId: userId, offlineLogin: true);

      String? lastError;
      for (var i = 0; i < OtpPolicy.maxAuthenticatorAttempts; i++) {
        lastError = await controller.verify('000000');
      }

      expect(lastError, contains('Too many attempts'));
      expect(controller.state.blocker, isNotNull);
    });

    test('with no authenticator enrolled, the step is skipped entirely',
        () async {
      final controller = OtpController(_FakeOtpRemote(), _FakeSecretStore());

      final outcome =
          await controller.issue(userId: userId, offlineLogin: true);

      expect(outcome, OtpIssueOutcome.skipped);
      expect(controller.state.channel, isNull);
      // Skipping offline must never touch the server.
    });

    test('never calls the remote send/verify endpoints', () async {
      final remote = _FakeOtpRemote();
      final store = _FakeSecretStore();
      await store.saveSecret(userId, TotpUtil.generateSecret());
      final controller = OtpController(remote, store);

      await controller.issue(userId: userId, offlineLogin: true);
      await controller.verify(TotpUtil.codeFor(await store.readSecret(userId) as String));

      expect(remote.sendCalls, 0);
      expect(remote.verifyCalls, 0);
    });
  });

  group('OtpController.resend', () {
    test('is a no-op on the authenticator channel', () async {
      final store = _FakeSecretStore();
      final secret = TotpUtil.generateSecret();
      await store.saveSecret(userId, secret);
      final remote = _FakeOtpRemote();
      final controller = OtpController(remote, store);
      await controller.issue(userId: userId, offlineLogin: true);

      final error = await controller.resend();

      expect(error, isNull);
      expect(remote.sendCalls, 0);
    });

    test('re-issues a fresh emailed code and resets the countdown', () async {
      final remote = _FakeOtpRemote()
        ..sendQueue.addAll([
          const OtpSendAccepted(
            destination: 'j***@example.com',
            validity: Duration(minutes: 5),
            resendAfter: Duration(seconds: 30),
          ),
          const OtpSendAccepted(
            destination: 'j***@example.com',
            validity: Duration(minutes: 5),
            resendAfter: Duration(seconds: 45),
          ),
        ]);
      final controller = OtpController(remote, _FakeSecretStore());
      await controller.issue(userId: userId, offlineLogin: false);

      final error = await controller.resend();

      expect(error, isNull);
      expect(remote.sendCalls, 2);
      expect(controller.state.resendAfter, const Duration(seconds: 45));
    });
  });

  group('TotpSecretStore', () {
    test('is keyed per user so a shared device cannot cross accounts',
        () async {
      final store = _FakeSecretStore();
      await store.saveSecret('user-a', 'SECRETAAAAAAAAAA');
      await store.saveSecret('user-b', 'SECRETBBBBBBBBBB');

      expect(await store.readSecret('user-a'), 'SECRETAAAAAAAAAA');
      expect(await store.readSecret('user-b'), 'SECRETBBBBBBBBBB');
      expect(await store.isEnrolled('user-c'), isFalse);
    });

    test('delete removes both the secret and the enrolment timestamp',
        () async {
      final store = _FakeSecretStore();
      await store.saveSecret(userId, 'SECRETAAAAAAAAAA');
      expect(await store.isEnrolled(userId), isTrue);

      await store.deleteSecret(userId);

      expect(await store.isEnrolled(userId), isFalse);
      expect(await store.enrolledAt(userId), isNull);
    });
  });
}
