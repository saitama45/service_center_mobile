import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/presentation/screens/profile/delete_account_dialog.dart';

/// Account deletion is irreversible and its entry point is one tap away from
/// the rest of Profile, so the dialog must never delete anything on the tap
/// that opened it.
///
/// Regression this guards: the Profile row used to open the web deletion
/// request immediately, with no confirmation of any kind in between.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<String?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const DeleteAccountDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the explanation, not on a password or a delete button',
      (tester) async {
    await open(tester);

    expect(find.text('Delete Account?'), findsOneWidget);
    expect(find.textContaining('unredeemed stamps and rewards are forfeited'),
        findsOneWidget);
    expect(find.text('Keep My Account'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Nothing here can submit anything.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Delete My Account'), findsNothing);
  });

  testWidgets('"Keep My Account" closes it without deleting', (tester) async {
    await open(tester);

    await tester.tap(find.text('Keep My Account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account?'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('"Continue" only advances to the password step', (tester) async {
    await open(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Deletion'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Delete My Account'), findsOneWidget);
  });

  testWidgets('the password step refuses an empty password', (tester) async {
    await open(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete My Account'));
    await tester.pumpAndSettle();

    // Still on the dialog, with an error — no request was made.
    expect(find.text('Enter your password to confirm.'), findsOneWidget);
    expect(find.text('Confirm Deletion'), findsOneWidget);
  });

  testWidgets('"Back" returns to the explanation and clears what was typed',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('hunter2'), findsNothing);
  });
}
