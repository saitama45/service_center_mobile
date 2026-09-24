// The in-app Forgot Password flow reads ghelpdesk's PasswordResetOtpController
// responses. The one ambiguous status is 422: a wrong code and a rejected
// password both use it, and the screen must tell them apart — a wrong code
// keeps the member on the code step, a weak password keeps them on the
// password step with the server's own rule message.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cbtl/data/datasources/remote/api_client.dart';
import 'package:cbtl/data/datasources/remote/password_reset_remote_datasource.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.status, this.body) : super(const FlutterSecureStorage());

  final int status;
  final Map<String, dynamic> body;
  String? lastPath;
  dynamic lastBody;

  @override
  Future<http.Response> post(String path, dynamic body,
      {Duration? timeout}) async {
    lastPath = path;
    lastBody = body;
    return http.Response(jsonEncode(this.body), status);
  }
}

void main() {
  test('forgot: 200 means sent, with the server cooldown', () async {
    final api = _FakeApi(200, {'expires_in': 600, 'resend_after': 30});
    final result =
        await PasswordResetRemoteDatasource(api).requestCode('a@b.com');

    expect(api.lastPath, '/api/password/forgot');
    expect(result, isA<PasswordResetCodeSent>());
    expect((result as PasswordResetCodeSent).resendAfter.inSeconds, 30);
  });

  test('forgot: 429 is throttled with retry_after', () async {
    final result = await PasswordResetRemoteDatasource(
            _FakeApi(429, {'message': 'Wait.', 'retry_after': 12}))
        .requestCode('a@b.com');

    expect(result, isA<PasswordResetThrottled>());
    expect((result as PasswordResetThrottled).retryAfter.inSeconds, 12);
  });

  test('verify: 422 without an errors map is a wrong code', () async {
    final result = await PasswordResetRemoteDatasource(_FakeApi(
            422, {'message': 'Incorrect code.', 'attempts_remaining': 3}))
        .verifyCode('a@b.com', '000000');

    expect(result, isA<PasswordResetWrongCode>());
    expect((result as PasswordResetWrongCode).attemptsRemaining, 3);
  });

  test('verify: 410 and 429 both mean the code is spent', () async {
    for (final status in [410, 429]) {
      final result = await PasswordResetRemoteDatasource(
              _FakeApi(status, {'message': 'Request a new one.'}))
          .verifyCode('a@b.com', '123456');
      expect(result, isA<PasswordResetCodeExpired>(), reason: '$status');
    }
  });

  test('reset: 422 with an errors map surfaces the password rule', () async {
    final result = await PasswordResetRemoteDatasource(_FakeApi(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'password': ['The password field must contain at least one symbol.'],
      },
    })).resetPassword(email: 'a@b.com', code: '123456', password: 'x');

    expect(result, isA<PasswordResetFailed>());
    expect((result as PasswordResetFailed).message, contains('symbol'));
  });

  test('reset: sends the confirmation the server requires', () async {
    final api = _FakeApi(200, {'message': 'ok'});
    final result = await PasswordResetRemoteDatasource(api).resetPassword(
        email: 'a@b.com', code: '123456', password: 'N3w-Passw0rd!');

    expect(result, isA<PasswordResetOk>());
    expect(api.lastPath, '/api/password/reset');
    expect(api.lastBody['password_confirmation'], 'N3w-Passw0rd!');
  });
}
