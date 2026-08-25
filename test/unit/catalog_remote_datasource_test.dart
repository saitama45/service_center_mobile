import 'package:flutter_test/flutter_test.dart';
import 'package:bms/data/datasources/remote/catalog_remote_datasource.dart';

void main() {
  group('RemoteCampaign.fromJson', () {
    test('maps every field the server can send', () {
      final campaign = RemoteCampaign.fromJson({
        'code': 'SP-3',
        'name': 'CBTL Campaign',
        'description': 'Collect stamps on any purchase',
        'emoji': '🍂',
        'tag': 'Hot Drinks',
        'required_stamps': 12,
        'eligible_items_description': 'Any hot beverage',
        'reward_description': 'One free drink',
        'terms_and_conditions': 'Terms apply.',
        'starts_at': '2026-01-01T00:00:00+00:00',
        'ends_at': '2026-12-31T23:59:59+00:00',
        'is_active': true,
        'display_order': 2,
      });

      expect(campaign.code, 'SP-3');
      expect(campaign.name, 'CBTL Campaign');
      expect(campaign.description, 'Collect stamps on any purchase');
      expect(campaign.emoji, '🍂');
      expect(campaign.tag, 'Hot Drinks');
      expect(campaign.requiredStamps, 12);
      expect(campaign.eligibleItemsDescription, 'Any hot beverage');
      expect(campaign.rewardDescription, 'One free drink');
      expect(campaign.termsAndConditions, 'Terms apply.');
      expect(campaign.startsAt, isNotNull);
      expect(campaign.endsAt, isNotNull);
      expect(campaign.isActive, isTrue);
      expect(campaign.displayOrder, 2);
    });

    test('falls back sensibly when optional fields are missing', () {
      final campaign = RemoteCampaign.fromJson({
        'code': 'SP-1',
        'name': 'Minimal Campaign',
      });

      expect(campaign.description, isNull);
      expect(campaign.emoji, isNull);
      expect(campaign.requiredStamps, 10); // documented fallback
      expect(campaign.startsAt, isNull);
      expect(campaign.endsAt, isNull);
      expect(campaign.isActive, isTrue); // fallback default
      expect(campaign.displayOrder, 0);
    });

    test('a missing name does not crash — falls back to a placeholder', () {
      final campaign = RemoteCampaign.fromJson({'code': 'SP-9'});
      expect(campaign.name, isNotEmpty);
    });

    test('an empty or unparseable date becomes null, not a throw', () {
      final campaign = RemoteCampaign.fromJson({
        'code': 'SP-2',
        'name': 'Bad Dates',
        'starts_at': '',
        'ends_at': 'not-a-date',
      });
      expect(campaign.startsAt, isNull);
      expect(campaign.endsAt, isNull);
    });

    test('required_stamps and display_order tolerate numeric strings', () {
      final campaign = RemoteCampaign.fromJson({
        'code': 'SP-4',
        'name': 'String Numbers',
        'required_stamps': '15',
        'display_order': '3',
      });
      expect(campaign.requiredStamps, 15);
      expect(campaign.displayOrder, 3);
    });

    test('is_active defaults true when the server omits it', () {
      final campaign = RemoteCampaign.fromJson({'code': 'SP-5', 'name': 'X'});
      expect(campaign.isActive, isTrue);
    });

    test('is_active respects an explicit false', () {
      final campaign = RemoteCampaign.fromJson({
        'code': 'SP-6',
        'name': 'Retired',
        'is_active': false,
      });
      expect(campaign.isActive, isFalse);
    });
  });
}
