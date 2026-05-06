import 'package:cloud_firestore/cloud_firestore.dart';

// Join document stored in setCards/{linkId}.
//
// This is the many-to-many link between a CardSet and a FlashCard.
// A card can appear in multiple sets; a set can contain multiple cards.
// userId is stored here so security rules can verify ownership without
// looking up the parent set or card document.
class SetCard {
  final String id; // Firestore document ID
  final String setId; // references sets/{setId}
  final String cardId; // references cards/{cardId}
  final String userId; // owner — used for security rule checks
  final DateTime addedAt;

  const SetCard({
    required this.id,
    required this.setId,
    required this.cardId,
    required this.userId,
    required this.addedAt,
  });

  factory SetCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SetCard(
      id: doc.id,
      setId: data['setId'] as String? ?? '',
      cardId: data['cardId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      addedAt: (data['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'setId': setId,
        'cardId': cardId,
        'userId': userId,
        'addedAt': Timestamp.fromDate(addedAt),
      };
}
