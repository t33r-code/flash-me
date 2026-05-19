import 'package:archive/archive.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/import_diff.dart';
import 'package:test/test.dart';

void main() {
  final baseDate = DateTime(2024, 1, 15);

  CardSet makeSet({String id = 'set-1', String name = 'Test Set'}) => CardSet(
        id: id,
        userId: 'user-1',
        name: name,
        cardCount: 0,
        createdAt: baseDate,
        updatedAt: baseDate,
      );

  FlashCard makeCard({String id = 'card-1', String word = 'hola'}) => FlashCard(
        id: id,
        primaryWord: word,
        translation: 'hello',
        fields: [],
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'user-1',
      );

  ImportCardData makeImportCard({String word = 'hola'}) => ImportCardData(
        primaryWord: word,
        translation: 'hello',
        rawFields: [],
      );

  // ── ImportSetDiff.isNewSet ─────────────────────────────────────────────────

  group('ImportSetDiff.isNewSet', () {
    test('true when existingSet is null', () {
      final diff = ImportSetDiff(
        setName: 'New Set',
        newCards: [],
        updatedCards: [],
        deletableCards: [],
      );
      expect(diff.isNewSet, isTrue);
    });

    test('false when existingSet is provided', () {
      final diff = ImportSetDiff(
        setName: 'Existing Set',
        existingSet: makeSet(),
        newCards: [],
        updatedCards: [],
        deletableCards: [],
      );
      expect(diff.isNewSet, isFalse);
    });
  });

  // ── ImportSetDiff.hasChanges ───────────────────────────────────────────────

  group('ImportSetDiff.hasChanges', () {
    test('false when all lists are empty', () {
      final diff = ImportSetDiff(
        setName: 'S',
        newCards: [],
        updatedCards: [],
        deletableCards: [],
      );
      expect(diff.hasChanges, isFalse);
    });

    test('true when newCards is non-empty', () {
      final diff = ImportSetDiff(
        setName: 'S',
        newCards: [NewCardEntry(makeImportCard())],
        updatedCards: [],
        deletableCards: [],
      );
      expect(diff.hasChanges, isTrue);
    });

    test('true when deletableCards is non-empty', () {
      final diff = ImportSetDiff(
        setName: 'S',
        newCards: [],
        updatedCards: [],
        deletableCards: [makeCard()],
      );
      expect(diff.hasChanges, isTrue);
    });

    test('true when libraryLinkCards is non-empty', () {
      final diff = ImportSetDiff(
        setName: 'S',
        newCards: [],
        libraryLinkCards: [
          LibraryLinkEntry(existingCard: makeCard(), incoming: makeImportCard()),
        ],
        updatedCards: [],
        deletableCards: [],
      );
      expect(diff.hasChanges, isTrue);
    });

    test('true when updatedCards is non-empty', () {
      final diff = ImportSetDiff(
        setName: 'S',
        newCards: [],
        updatedCards: [
          UpdatedCardEntry(
            existing: makeCard(),
            incoming: makeImportCard(),
            changes: [
              const FieldChange(label: 'translation', oldValue: 'hello', newValue: 'hi'),
            ],
          ),
        ],
        deletableCards: [],
      );
      expect(diff.hasChanges, isTrue);
    });
  });

  // ── ImportAnalysis computed totals ─────────────────────────────────────────

  group('ImportAnalysis computed totals', () {
    test('sums newCards across multiple diffs', () {
      final diff1 = ImportSetDiff(
        setName: 'S1',
        newCards: [NewCardEntry(makeImportCard()), NewCardEntry(makeImportCard())],
        updatedCards: [],
        deletableCards: [],
      );
      final diff2 = ImportSetDiff(
        setName: 'S2',
        newCards: [NewCardEntry(makeImportCard())],
        updatedCards: [],
        deletableCards: [],
      );
      final analysis = ImportAnalysis(setDiffs: [diff1, diff2], archive: Archive());
      expect(analysis.totalNewCards, equals(3));
    });

    test('sums deletableCards across multiple diffs', () {
      final diff1 = ImportSetDiff(
        setName: 'S1',
        newCards: [],
        updatedCards: [],
        deletableCards: [makeCard(id: 'c1'), makeCard(id: 'c2')],
      );
      final diff2 = ImportSetDiff(
        setName: 'S2',
        newCards: [],
        updatedCards: [],
        deletableCards: [makeCard(id: 'c3')],
      );
      final analysis = ImportAnalysis(setDiffs: [diff1, diff2], archive: Archive());
      expect(analysis.totalDeletableCards, equals(3));
    });

    test('all totals are zero for an empty analysis', () {
      final analysis = ImportAnalysis(setDiffs: [], archive: Archive());
      expect(analysis.totalNewCards, equals(0));
      expect(analysis.totalUpdatedCards, equals(0));
      expect(analysis.totalDeletableCards, equals(0));
      expect(analysis.totalLibraryLinkCards, equals(0));
    });
  });
}
