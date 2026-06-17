import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// Join document stored in setCards/{linkId}.
//
// Many-to-many link between a CardSet and a card (flash or workbook).
// cardType tells the reader which Firestore collection cardId belongs to.
// Existing documents without cardType default to 'flashcard' (backward compatible).
// userId is stored here so security rules can verify ownership without
// looking up the parent set or card document.
class SetCard {
  final String id; // Firestore document ID
  final String setId; // references sets/{setId}
  // References cards/{cardId} or workbookCards/{cardId} depending on cardType.
  final String cardId;
  final String userId; // owner — used for security rule checks
  final DateTime addedAt;
  // AppConstants.cardTypeFlashcard | AppConstants.cardTypeWorkbook
  final String cardType;

  const SetCard({
    required this.id,
    required this.setId,
    required this.cardId,
    required this.userId,
    required this.addedAt,
    this.cardType = AppConstants.cardTypeFlashcard,
  });

  factory SetCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SetCard(
      id: doc.id,
      setId: data['setId'] as String? ?? '',
      cardId: data['cardId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      addedAt: (data['addedAt'] as Timestamp).toDate(),
      // Absent field on old documents defaults to flashcard.
      cardType: data['cardType'] as String? ?? AppConstants.cardTypeFlashcard,
    );
  }

  // No user-entered fields — all values are system-supplied.
  List<String> validate() => [];

  Map<String, dynamic> toFirestore() => {
        'setId': setId,
        'cardId': cardId,
        'userId': userId,
        'addedAt': Timestamp.fromDate(addedAt),
        'cardType': cardType,
      };
}
