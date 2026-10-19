// Profile → Suggestion Box. The screen must never send an empty message,
// must keep what the member typed when sending fails (nothing is queued
// offline, so the text on screen is the only copy), and must return to
// Profile with a thank-you once the server has it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cbtl/data/datasources/remote/api_client.dart';
import 'package:cbtl/data/datasources/remote/suggestion_remote_datasource.dart';
import 'package:cbtl/presentation/providers/app_providers.dart';
import 'package:cbtl/presentation/screens/profile/suggestion_box_screen.dart';

class _FakeDatasource extends SuggestionRemoteDatasource {
  _FakeDatasource(this.outcome) : super(ApiClient(const FlutterSecureStorage()));

  final SuggestionOutcome outcome;
  int calls = 0;
  String? lastSubject;
  String? lastMessage;

  @override
  Future<SuggestionOutcome> send({String? subject, required String message}) async {
    calls++;
    lastSubject = subject;
    lastMessage = message;
    return outcome;
  }
}

Future<void> _pump(WidgetTester tester, _FakeDatasource fake) async {
  final router = GoRouter(
    initialLocation: '/dashboard/profile/suggestion-box',
    routes: [
      GoRoute(
        path: '/dashboard/profile',
        builder: (_, __) => const Scaffold(body: Text('PROFILE')),
        routes: [
          GoRoute(
            path: 'suggestion-box',
            builder: (_, __) => const SuggestionBoxScreen(),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [suggestionRemoteDatasourceProvider.overrideWithValue(fake)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapSend(WidgetTester tester) async {
  final send = find.text('Send Message');
  await tester.ensureVisible(send);
  await tester.tap(send);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty message is refused before anything is sent',
      (tester) async {
    final fake = _FakeDatasource(const SuggestionSent());
    await _pump(tester, fake);

    await tester.enterText(find.byType(TextFormField).at(1), '   ');
    await _tapSend(tester);

    expect(find.text('Please write a message'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('a failed send shows why and keeps the text', (tester) async {
    final fake = _FakeDatasource(const SuggestionFailed('No connection.'));
    await _pump(tester, fake);

    await tester.enterText(find.byType(TextFormField).at(1), 'More seats');
    await _tapSend(tester);

    expect(find.text('No connection.'), findsOneWidget);
    expect(find.text('More seats'), findsOneWidget);
    expect(find.text('PROFILE'), findsNothing);
  });

  testWidgets('a sent message thanks the member and returns to Profile',
      (tester) async {
    final fake = _FakeDatasource(const SuggestionSent());
    await _pump(tester, fake);

    await tester.enterText(find.byType(TextFormField).at(0), 'Seating');
    await tester.enterText(find.byType(TextFormField).at(1), 'More seats');
    await _tapSend(tester);

    expect(fake.calls, 1);
    expect(fake.lastSubject, 'Seating');
    expect(fake.lastMessage, 'More seats');
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('Thank you! Your message has been sent.'), findsOneWidget);
  });
}
