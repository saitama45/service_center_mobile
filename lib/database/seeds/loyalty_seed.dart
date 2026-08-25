import 'package:drift/drift.dart';
import '../app_database.dart';

/// Catalogue seeded on first run. Product codes are the stable identifiers
/// campaigns match against, so changing a name later is safe but changing a
/// code is not.
List<ProductsCompanion> productsSeedData() => const [
      ProductsCompanion(
        code: Value('PROD-001'),
        name: Value('Oat Milk Cortado'),
        category: Value('Hot Drinks'),
        emoji: Value('☕'),
        price: Value(165),
      ),
      ProductsCompanion(
        code: Value('PROD-002'),
        name: Value('Flat White'),
        category: Value('Hot Drinks'),
        emoji: Value('☕'),
        price: Value(155),
      ),
      ProductsCompanion(
        code: Value('PROD-003'),
        name: Value('Cappuccino Large'),
        category: Value('Hot Drinks'),
        emoji: Value('☕'),
        price: Value(170),
      ),
      ProductsCompanion(
        code: Value('PROD-004'),
        name: Value('Autumn Harvest Latte'),
        category: Value('Hot Drinks'),
        emoji: Value('🍂'),
        price: Value(195),
      ),
      ProductsCompanion(
        code: Value('PROD-005'),
        name: Value('Cold Brew Grande'),
        category: Value('Cold Drinks'),
        emoji: Value('🧊'),
        price: Value(180),
      ),
      ProductsCompanion(
        code: Value('PROD-006'),
        name: Value('Iced Matcha Latte'),
        category: Value('Cold Drinks'),
        emoji: Value('🍵'),
        price: Value(190),
      ),
      ProductsCompanion(
        code: Value('PROD-007'),
        name: Value('Iced Americano'),
        category: Value('Cold Drinks'),
        emoji: Value('🧊'),
        price: Value(140),
      ),
      ProductsCompanion(
        code: Value('PROD-008'),
        name: Value('Double Espresso'),
        category: Value('Espresso'),
        emoji: Value('☀️'),
        price: Value(130),
      ),
      ProductsCompanion(
        code: Value('PROD-009'),
        name: Value('Ristretto'),
        category: Value('Espresso'),
        emoji: Value('☀️'),
        price: Value(125),
      ),
    ];

/// Campaigns mirroring the three in the reference design.
List<CampaignsCompanion> campaignsSeedData() {
  final now = DateTime.now().toUtc();
  DateTime inDays(int d) => DateTime.utc(now.year, now.month, now.day + d);

  return [
    CampaignsCompanion(
      code: const Value('AUTUMN_HARVEST'),
      name: const Value('Autumn Harvest Latte'),
      description:
          const Value('Collect 10 stamps on any hot beverage purchase'),
      emoji: const Value('🍂'),
      tag: const Value('Hot Drinks'),
      requiredStamps: const Value(10),
      eligibleProductCodes:
          const Value('PROD-001,PROD-002,PROD-003,PROD-004'),
      rewardDescription: const Value('One free Autumn Harvest Latte'),
      termsAndConditions: const Value(
        'Valid at participating locations only. One reward per stamp card '
        'cycle. Cannot be combined with other offers. Management reserves the '
        'right to modify or cancel campaigns at any time without notice.',
      ),
      startsAt: Value(inDays(-30)),
      endsAt: Value(inDays(120)),
      displayOrder: const Value(1),
    ),
    CampaignsCompanion(
      code: const Value('COLD_BREW_BUNDLE'),
      name: const Value('Cold Brew Bundle'),
      description:
          const Value('Earn stamps on cold beverages after 2PM daily'),
      emoji: const Value('🧊'),
      tag: const Value('Cold Drinks'),
      requiredStamps: const Value(8),
      eligibleProductCodes: const Value('PROD-005,PROD-006,PROD-007'),
      rewardDescription: const Value('One free Cold Brew Grande'),
      termsAndConditions: const Value(
        'Stamps are earned on cold beverage purchases made after 2:00 PM. '
        'One reward per stamp card cycle. Not valid with other promotions.',
      ),
      startsAt: Value(inDays(-14)),
      endsAt: Value(inDays(150)),
      displayOrder: const Value(2),
    ),
    CampaignsCompanion(
      code: const Value('MORNING_ESPRESSO'),
      name: const Value('Morning Espresso'),
      description:
          const Value('Before 9AM purchases — 6 stamps for a free shot'),
      emoji: const Value('☀️'),
      tag: const Value('Espresso'),
      requiredStamps: const Value(6),
      eligibleProductCodes: const Value('PROD-008,PROD-009'),
      rewardDescription: const Value('One free espresso shot'),
      termsAndConditions: const Value(
        'Valid on espresso-based purchases before 9:00 AM. One reward per '
        'stamp card cycle. Dine-in and takeaway both qualify.',
      ),
      startsAt: Value(inDays(-60)),
      endsAt: Value(inDays(90)),
      displayOrder: const Value(3),
    ),
  ];
}
