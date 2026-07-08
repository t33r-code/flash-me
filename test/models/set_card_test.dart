import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  final addedAt = DateTime(2024, 3, 1);

  SetCard make({int? position}) => SetCard(
        id: 'link-1',
        setId: 'set-1',
        cardId: 'card-1',
        userId: 'user-1',
        addedAt: addedAt,
        position: position,
      );

  group('SetCard.toFirestore', () {
    test('writes position when assigned', () {
      final map = make(position: 3).toFirestore();
      expect(map['position'], equals(3));
      expect(map['cardId'], equals('card-1'));
      expect(map['cardType'], equals(AppConstants.cardTypeFlashcard));
    });

    test('omits position when null (keeps legacy docs untouched)', () {
      final map = make().toFirestore();
      expect(map.containsKey('position'), isFalse);
    });

    test('position 0 is written (not treated as absent)', () {
      final map = make(position: 0).toFirestore();
      expect(map['position'], equals(0));
    });
  });
}
