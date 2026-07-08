import 'package:flash_me/models/card_set.dart';
import 'package:test/test.dart';

void main() {
  final baseDate = DateTime(2024, 1, 15);

  CardSet make({bool? enforceOrder}) => CardSet(
        id: 'set-1',
        userId: 'user-1',
        name: 'Spanish Verbs',
        cardCount: 0,
        createdAt: baseDate,
        updatedAt: baseDate,
        enforceOrder: enforceOrder ?? false,
      );

  group('CardSet.enforceOrder', () {
    test('defaults to false', () {
      expect(make().enforceOrder, isFalse);
    });

    test('serialized to Firestore and JSON', () {
      final on = make(enforceOrder: true);
      expect(on.toFirestore()['enforceOrder'], isTrue);
      expect(on.toJson()['enforceOrder'], isTrue);
      expect(make().toFirestore()['enforceOrder'], isFalse);
    });

    test('copyWith updates the flag', () {
      final updated = make().copyWith(enforceOrder: true);
      expect(updated.enforceOrder, isTrue);
    });

    test('copyWith preserves the flag when omitted', () {
      final updated = make(enforceOrder: true).copyWith(name: 'Renamed');
      expect(updated.enforceOrder, isTrue);
      expect(updated.name, equals('Renamed'));
    });
  });
}
