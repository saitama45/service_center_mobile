import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/data/datasources/remote/loyalty_member_remote_datasource.dart';

/// Parsing of `my-cards` / `my-transactions` rows, with and without the
/// Holiday-slot fields. An older server omits all of them, and the app has to
/// read its rows exactly as it did before they existed.
void main() {
  group('RemoteCardProgress.fromJson', () {
    test('reads the Holiday-slot fields', () {
      final card = RemoteCardProgress.fromJson({
        'code': 'SP-7',
        'card_id': 77,
        'stamps_count': 6,
        'stamps_required': 20,
        'status': 'active',
        'holiday_stamps': 4,
        'holiday_count': 4,
        'regular_count': 2,
        'card_number': 1,
        'max_cards': 3,
      });

      expect(card.cardId, '77');
      expect(card.stampsCount, 6);
      expect(card.holidayStamps, 4);
      expect(card.holidayCount, 4);
      expect(card.regularCount, 2);
      expect(card.cardNumber, 1);
      expect(card.maxCards, 3);
    });

    test('an older server without them reads as a plain card', () {
      final card = RemoteCardProgress.fromJson({
        'code': 'SP-3',
        'card_id': 12,
        'stamps_count': 5,
        'stamps_required': 12,
        'status': 'active',
      });

      expect(card.holidayStamps, 0);
      expect(card.holidayCount, 0);
      expect(card.regularCount, 5, reason: 'every stamp is a regular one');
      expect(card.cardNumber, isNull);
      expect(card.maxCards, isNull);
    });

    test('regular_count is derived when only holiday_count is sent', () {
      final card = RemoteCardProgress.fromJson({
        'code': 'SP-7',
        'stamps_count': 7,
        'holiday_count': '3',
      });
      expect(card.holidayCount, 3);
      expect(card.regularCount, 4);
    });

    test('nonsense values fall back instead of throwing', () {
      final card = RemoteCardProgress.fromJson({
        'code': 'SP-7',
        'stamps_count': 2,
        'holiday_count': -1,
        'regular_count': 'many',
        'card_number': 0,
        'max_cards': 'none',
      });
      expect(card.holidayCount, 0);
      expect(card.regularCount, 2);
      expect(card.cardNumber, isNull, reason: 'card numbers are 1-based');
      expect(card.maxCards, isNull);
    });
  });

  group('RemoteTransaction.fromJson', () {
    test('reads card_id and stamp_type on an earn', () {
      final txn = RemoteTransaction.fromJson({
        'reference': 'SE-42',
        'type': 'earn',
        'points': 1,
        'campaign_code': 'SP-7',
        'card_id': 78,
        'stamp_type': 'holiday',
      });
      expect(txn.cardId, '78');
      expect(txn.stampType, 'holiday');
      expect(txn.isHolidayStamp, isTrue);
    });

    test('a redemption carries card_id and no stamp type', () {
      final txn = RemoteTransaction.fromJson({
        'reference': 'SR-7',
        'type': 'redeem',
        'points': -20,
        'campaign_code': 'SP-7',
        'card_id': '77',
      });
      expect(txn.cardId, '77');
      expect(txn.stampType, isNull);
      expect(txn.isHolidayStamp, isFalse);
    });

    test('an older server without them leaves both null', () {
      final txn = RemoteTransaction.fromJson({
        'reference': 'SE-1',
        'type': 'earn',
        'points': 1,
        'campaign_code': 'SP-3',
      });
      expect(txn.cardId, isNull);
      expect(txn.stampType, isNull);
    });

    test('an unknown stamp_type is treated as absent', () {
      final txn = RemoteTransaction.fromJson({
        'reference': 'SE-2',
        'type': 'earn',
        'campaign_code': 'SP-3',
        'card_id': '',
        'stamp_type': 'Bonus',
      });
      expect(txn.cardId, isNull);
      expect(txn.stampType, isNull);
    });

    test('stamp_type is case-insensitive', () {
      final txn = RemoteTransaction.fromJson({
        'reference': 'SE-3',
        'type': 'earn',
        'campaign_code': 'SP-3',
        'stamp_type': ' Regular ',
      });
      expect(txn.stampType, 'regular');
    });
  });
}
