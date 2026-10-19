// Profile → Suggestion Box posts to ghelpdesk's Api\SuggestionController.
// The screen only distinguishes "sent" from "show this message", so what
// matters is that each status lands on the right outcome with the most
// specific text the server gave.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cbtl/data/datasources/remote/api_client.dart';
import 'package:cbtl/data/datasources/remote/suggestion_remote_datasource.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.status, this.body, {this.error})
      : super(const FlutterSecureStorage());

  final int status;
  final Map<String, dynamic> body;
  final Object? error;
  String? lastPath;
  dynamic lastBody;

  @override
  Future<http.Response> post(String path, dynamic body,
      {Duration? timeout}) async {
    lastPath = path;
    lastBody = body;
    if (error != null) throw error!;
    return http.Response(jsonEncode(this.body), status);
  }
}

void main() {
  test('201 is sent; the body is trimmed and a blank subject is omitted',
      () async {
    final api = _FakeApi(201, {'id': 1, 'message': 'Thank you!'});
    final result = await SuggestionRemoteDatasource(api)
        .send(subject: '   ', message: '  More oat milk, please.\n');

    expect(result, isA<SuggestionSent>());
    expect(api.lastPath, '/api/loyalty/suggestions');
    expect(api.lastBody, {'message': 'More oat milk, please.'});
  });

  test('a subject is sent when given', () async {
    final api = _FakeApi(201, {'id': 1});
    await SuggestionRemoteDatasource(api)
        .send(subject: ' Seating ', message: 'More seats');

    expect(api.lastBody, {'subject': 'Seating', 'message': 'More seats'});
  });

  test('422 surfaces the first field error', () async {
    final result = await SuggestionRemoteDatasource(_FakeApi(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'message': ['The message field must not be greater than 2000 characters.'],
      },
    })).send(message: 'x');

    expect(result, isA<SuggestionRejected>());
    expect((result as SuggestionRejected).message,
        'The message field must not be greater than 2000 characters.');
  });

  test('429 and server errors fail with the server message', () async {
    for (final status in [429, 500]) {
      final result = await SuggestionRemoteDatasource(
              _FakeApi(status, {'message': 'Slow down.'}))
          .send(message: 'Hi');
      expect(result, isA<SuggestionFailed>(), reason: '$status');
      expect((result as SuggestionFailed).message, 'Slow down.');
    }
  });

  test('a network error fails without throwing', () async {
    final result = await SuggestionRemoteDatasource(
            _FakeApi(0, const {}, error: http.ClientException('offline')))
        .send(message: 'Hi');

    expect(result, isA<SuggestionFailed>());
  });
}
