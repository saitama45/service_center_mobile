// The reported journey: a member registers, staff delete the account in
// ghelpdesk (User Management + Stamps -> Customers), the member registers again
// from the same phone. The second sign-up used to end on "Could not connect to
// the server" — while the server had in fact created the account.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bms/core/errors/failures.dart';
import 'package:bms/data/datasources/remote/api_client.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/domain/usecases/auth/login_usecase.dart';

/// Scripted stand-in for the server round trip — same pattern as the fakes in
/// sync_manager_test.dart, one level lower (the raw HTTP response).
class _ScriptedApiClient extends ApiClient {
  _ScriptedApiClient() : super(const FlutterSecureStorage());

  final List<http.Response> queue = [];
  final List<String> paths = [];
  Object? throwOnPost;

  @override
  Future<http.Response> post(String path, dynamic body, {Duration? timeout}) async {
    paths.add(path);
    if (throwOnPost != null) throw throwOnPost!;
    return queue.removeAt(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ScriptedApiClient api;
  late RegisterUseCase useCase;

  const email = 'garudaperez45@gmail.com';
  const password = r'Str0ng!pass';

  http.Response created(String id) => http.Response(
        jsonEncode({
          'token': 'token-$id',
          'user': {
            'id': id,
            'name': 'Gen',
            'email': email,
            'profile_photo': null,
          },
          'roles': <String>[],
        }),
        201,
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _ScriptedApiClient();
    useCase = RegisterUseCase(db, const FlutterSecureStorage(), api);
  });

  tearDown(() async => db.close());

  Future<RegisterResult> register() => useCase.call(
        name: 'Gen',
        email: email,
        password: password,
      );

  test('registering again after the account was deleted signs the member in',
      () async {
    api.queue.add(created('101'));
    expect(await register(), isA<RegisterSuccess>());

    // Account deleted server-side; signing up again returns a NEW users.id.
    api.queue.add(created('137'));
    final result = await register();

    expect(result, isA<RegisterSuccess>());
    expect((result as RegisterSuccess).user.id, '137');

    final rows = await db.select(db.users).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, '137');
  });

  test('a rejected email is reported as the server worded it', () async {
    api.queue.add(http.Response(
      jsonEncode({
        'message': 'The email has already been taken.',
        'errors': {
          'email': ['The email has already been taken.'],
        },
      }),
      422,
    ));

    final result = await register();

    expect(result, isA<RegisterFailure>());
    final failure = (result as RegisterFailure).failure;
    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'The email has already been taken.');
  });

  test('an unreachable server is still a connection failure', () async {
    api.throwOnPost = const SocketExceptionStub();

    final result = await register();

    expect(result, isA<RegisterFailure>());
    expect((result as RegisterFailure).failure, isA<NetworkFailure>());
  });

  test('a local failure after the account was created is not blamed on the network',
      () async {
    // Anything that goes wrong once the server answered 201 must not tell the
    // member to check their connection: the account exists, and retrying only
    // hands them "the email has already been taken".
    api.queue.add(http.Response('not json', 201));

    final result = await register();

    expect(result, isA<RegisterFailure>());
    final failure = (result as RegisterFailure).failure;
    expect(failure, isNot(isA<NetworkFailure>()));
    expect(failure.message, contains('account was created'));
  });
}

/// Stand-in for a dropped connection — the use case only cares that the call
/// threw, not which socket error it was.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
