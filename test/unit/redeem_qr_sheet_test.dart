import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/daos/loyalty_dao.dart';
import 'package:bms/presentation/providers/auth_provider.dart';
import 'package:bms/presentation/providers/loyalty_provider.dart';
import 'package:bms/presentation/screens/campaigns/redeem_qr_sheet.dart';

/// The "Redeem Now" sheet must stay open until ghelpdesk staff actually
/// redeem the card.
///
/// Regression: it used to close within a second of opening, announcing
/// "Reward redeemed. Enjoy!" before anyone had scanned anything. The sheet
/// inferred the redemption from the card DISAPPEARING out of
/// `campaignProgressProvider` (which drops redeemed cards) — but a provider
/// being *refreshed* looks identical through `maybeWhen(data:)` while still
/// reporting `hasValue`, and the sync fired on open triggers exactly that
/// refresh. It now watches the card's own row for a positive `redeemed_at`.
void main() {
  late AppDatabase db;
  late Campaign campaign;

  /// The list the sheet sees; the test drives it like the sync would.
  final feed = StateProvider<List<CampaignProgress>>((ref) => const []);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    campaign = await db.into(db.campaigns).insertReturning(
          CampaignsCompanion.insert(
              code: 'SP-3',
              name: 'CBTL Campaign',
              requiredStamps: const Value(12)),
        );
  });
  tearDown(() async => db.close());

  Future<CampaignProgress> cardProgress({DateTime? redeemedAt}) async {
    final card = await db.into(db.stampCards).insertReturning(
          StampCardsCompanion.insert(
            userId: 'user-1',
            campaignId: campaign.id,
            stampsCollected: const Value(12),
            completedAt: Value(DateTime.utc(2026, 9, 4)),
            remoteCardId: const Value('9'),
            redeemToken: const Value('LRDM1:9:0123456789abcdef01234567'),
            redeemedAt: Value(redeemedAt),
          ),
        );
    return CampaignProgress(campaign: campaign, card: card);
  }

  /// `currentUserProvider` is overridden to null so the sheet's own
  /// `SyncManager.sync()` call short-circuits — this is about what the sheet
  /// does with provider states, not about the network.
  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      campaignCardsProvider.overrideWith((ref) async => ref.watch(feed)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> openSheet(
    WidgetTester tester,
    ProviderContainer container,
    CampaignProgress opened,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showRedeemQrSheet(context, opened),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Explicit pumps, never pumpAndSettle: the sheet runs a "waiting for the
    // cashier" spinner and a poll timer, so the tree never goes quiet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stays open while the card is still unredeemed', (tester) async {
    final unlocked = await cardProgress();
    final container = makeContainer();
    container.read(feed.notifier).state = [unlocked];

    await openSheet(tester, container, unlocked);
    expect(find.text('Show this to the cashier to claim it.'), findsOneWidget);

    // Well past several poll cycles — the old bug closed it inside the first.
    await tester.pump(const Duration(seconds: 15));

    expect(find.text('Show this to the cashier to claim it.'), findsOneWidget,
        reason: 'nobody has scanned the code yet');
    expect(find.text('Reward redeemed. Enjoy!'), findsNothing);
  });

  testWidgets('shows its code even while the card list is still loading',
      (tester) async {
    final unlocked = await cardProgress();
    // feed left empty: the provider resolves to a list without this card.
    final container = makeContainer();

    await openSheet(tester, container, unlocked);

    expect(find.text('Waiting for the cashier to scan…'), findsOneWidget);
    expect(find.textContaining("isn't ready yet"), findsNothing,
        reason: 'the code it was opened with must not blank out');
  });

  testWidgets('closes once the card actually reads as redeemed',
      (tester) async {
    final unlocked = await cardProgress();
    final container = makeContainer();
    container.read(feed.notifier).state = [unlocked];

    await openSheet(tester, container, unlocked);
    expect(find.text('Show this to the cashier to claim it.'), findsOneWidget);

    // Staff redeem it in ghelpdesk; the progress pull sets redeemed_at on
    // this same card row.
    container.read(feed.notifier).state = [
      CampaignProgress(
        campaign: campaign,
        card: unlocked.card!.copyWith(
          redeemedAt: Value(DateTime.utc(2026, 9, 5)),
          redeemToken: const Value(null),
        ),
      ),
    ];
    // The provider re-runs asynchronously, then the post-frame callback pops
    // the route and the exit animation plays — several pumps, not one.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Show this to the cashier to claim it.'), findsNothing);
    expect(find.text('Reward redeemed. Enjoy!'), findsOneWidget);
  });
}
