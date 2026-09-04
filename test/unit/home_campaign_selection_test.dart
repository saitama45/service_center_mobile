import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/daos/loyalty_dao.dart';
import 'package:bms/presentation/providers/loyalty_provider.dart';

/// Home's campaign switcher: which card the hero shows when a member is
/// collecting on more than one campaign at a time.
///
/// Real Drift rows rather than hand-built stubs, so `CampaignProgress`
/// behaves exactly as it does on device (`isUnlocked`, `isExpired`, …).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<CampaignProgress> progressFor({
    required String code,
    required String name,
    required int required_,
    required int collected,
    DateTime? endsAt,
    DateTime? redeemedAt,
  }) async {
    final campaign = await db.into(db.campaigns).insertReturning(
          CampaignsCompanion.insert(
            code: code,
            name: name,
            requiredStamps: Value(required_),
            endsAt: Value(endsAt),
          ),
        );
    final card = await db.into(db.stampCards).insertReturning(
          StampCardsCompanion.insert(
            userId: 'user-1',
            campaignId: campaign.id,
            stampsCollected: Value(collected),
            redeemedAt: Value(redeemedAt),
          ),
        );
    return CampaignProgress(campaign: campaign, card: card);
  }

  /// Wires the two providers Home derives everything else from.
  ProviderContainer containerWith(
    List<CampaignProgress> all,
    CampaignProgress? featured,
  ) {
    final container = ProviderContainer(overrides: [
      campaignProgressProvider.overrideWith((ref) async => all),
      featuredCampaignProvider.overrideWith((ref) async => featured),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('with no pick, Home shows the automatic choice', () async {
    final espresso = await progressFor(
        code: 'SP-3', name: 'Espresso', required_: 12, collected: 4);
    final latte = await progressFor(
        code: 'SP-4', name: 'Latte', required_: 10, collected: 9);

    final container = containerWith([espresso, latte], latte);

    final shown = await container.read(homeCampaignProvider.future);
    expect(shown?.campaign.name, 'Latte');
  });

  test('picking a campaign switches the card to it', () async {
    final espresso = await progressFor(
        code: 'SP-3', name: 'Espresso', required_: 12, collected: 4);
    final latte = await progressFor(
        code: 'SP-4', name: 'Latte', required_: 10, collected: 9);

    final container = containerWith([espresso, latte], latte);

    container.read(selectedHomeCampaignIdProvider.notifier).state =
        espresso.campaign.id;

    final shown = await container.read(homeCampaignProvider.future);
    expect(shown?.campaign.name, 'Espresso');
    expect(shown?.stamps, 4, reason: 'the count shown must be that campaign\'s own');
  });

  test('a pick that disappears falls back instead of showing nothing', () async {
    // Exactly what a redemption does: the card leaves getCampaignProgress,
    // so the id the member picked is no longer in the list.
    final espresso = await progressFor(
        code: 'SP-3', name: 'Espresso', required_: 12, collected: 4);
    final latte = await progressFor(
        code: 'SP-4', name: 'Latte', required_: 10, collected: 9);

    final container = containerWith([latte], latte);
    container.read(selectedHomeCampaignIdProvider.notifier).state =
        espresso.campaign.id;

    final shown = await container.read(homeCampaignProvider.future);
    expect(shown?.campaign.name, 'Latte');
  });

  test('expired campaigns are not offered as a choice', () async {
    final live = await progressFor(
        code: 'SP-3', name: 'Espresso', required_: 12, collected: 4);
    final expired = await progressFor(
      code: 'SP-4',
      name: 'Last Summer',
      required_: 10,
      collected: 2,
      endsAt: DateTime.utc(2020, 1, 1),
    );

    final container = containerWith([live, expired], live);

    final choices = await container.read(homeCampaignChoicesProvider.future);
    expect(choices.map((p) => p.campaign.name), ['Espresso']);
  });

  test('an expired campaign cannot be selected into the hero', () async {
    final live = await progressFor(
        code: 'SP-3', name: 'Espresso', required_: 12, collected: 4);
    final expired = await progressFor(
      code: 'SP-4',
      name: 'Last Summer',
      required_: 10,
      collected: 2,
      endsAt: DateTime.utc(2020, 1, 1),
    );

    final container = containerWith([live, expired], live);
    container.read(selectedHomeCampaignIdProvider.notifier).state =
        expired.campaign.id;

    final shown = await container.read(homeCampaignProvider.future);
    expect(shown?.campaign.name, 'Espresso',
        reason: 'collecting on it is impossible, so it must not take the hero');
  });

  test('no campaigns at all still resolves to null, not an error', () async {
    final container = containerWith([], null);
    expect(await container.read(homeCampaignProvider.future), isNull);
  });
}
