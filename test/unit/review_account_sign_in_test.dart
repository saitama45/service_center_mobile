// Google Play rejected the app (2026-11-25) because its reviewer, signing in
// with the demo account, stopped at "We sent a 6-digit code to g***@gmail.com".
// ghelpdesk now answers `otp_required: false` for the store-review accounts
// alone, and the app must skip the code step for them, and only for them.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cbtl/data/datasources/remote/api_client.dart';
import 'package:cbtl/database/app_database.dart';
import 'package:cbtl/domain/usecases/auth/login_usecase.dart';
import 'package:cbtl/presentation/providers/auth_flow_provider.dart';

/// Answers every POST with the next scripted response.
class _ScriptedApiClient extends ApiClient {
  _ScriptedApiClient() : super(const FlutterSecureStorage());

  final List<http.Response> queue = [];

  @override
  Future<http.Response> post(String path, dynamic body,
      {Duration? timeout}) async {
    return queue.removeAt(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ScriptedApiClient api;

  const email = 'reviewer@example.com';
  const password = r'Str0ng!pass';

  /// The `/api/login` / `/api/register` body. [otpRequired] is the raw JSON
  /// value; [omit] leaves the field out, as servers before the flag do.
  http.Response signedIn(Object? otpRequired,
          {int status = 200, bool omit = false}) =>
      http.Response(
        jsonEncode({
          'token': 'token-1',
          'user': {
            'id': '41',
            'name': 'Play Reviewer',
            'email': email,
            'profile_photo': null,
          },
          'roles': <String>[],
          if (!omit) 'otp_required': otpRequired,
        }),
        status,
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _ScriptedApiClient();
  });

  tearDown(() async => db.close());

  Future<LoginSuccess> login() async {
    final result =
        await LoginUseCase(db, const FlutterSecureStorage(), api)(email, password);
    expect(result, isA<LoginSuccess>());
    return result as LoginSuccess;
  }

  group('sign-in response', () {
    test('a review account the server exempts skips the code step', () async {
      api.queue.add(signedIn(false));
      expect((await login()).otpRequired, isFalse);
    });

    test('an ordinary member still gets the code step', () async {
      api.queue.add(signedIn(true));
      expect((await login()).otpRequired, isTrue);
    });

    test('a server from before the flag changes nothing', () async {
      api.queue.add(signedIn(null, omit: true));
      expect((await login()).otpRequired, isTrue);
    });

    test('only a real JSON false exempts the account', () async {
      for (final value in <Object?>[null, 'false', 0, '']) {
        api.queue.add(signedIn(value));
        expect((await login()).otpRequired, isTrue, reason: 'value: $value');
      }
    });
  });

  group('sign-up response', () {
    Future<RegisterSuccess> register() async {
      final result = await RegisterUseCase(db, const FlutterSecureStorage(), api)
          .call(name: 'Play Reviewer', email: email, password: password);
      expect(result, isA<RegisterSuccess>());
      return result as RegisterSuccess;
    }

    test('a review account signing up again skips the code step', () async {
      api.queue.add(signedIn(false, status: 201));
      expect((await register()).otpRequired, isFalse);
    });

    test('a new member still gets the code step', () async {
      api.queue.add(signedIn(true, status: 201));
      expect((await register()).otpRequired, isTrue);
    });
  });

  group('post-login steps', () {
    test('an exempt sign-in starts at the biometric offer', () {
      final steps = PostLoginStepNotifier()
        ..beginVerification(offline: false, otpRequired: false);
      expect(steps.state, PostLoginStep.biometric);
    });

    test('every other sign-in starts at the code step', () {
      final steps = PostLoginStepNotifier()..beginVerification(offline: false);
      expect(steps.state, PostLoginStep.otp);
      steps.beginVerification(offline: true);
      expect(steps.state, PostLoginStep.otp);
    });
  });
}
