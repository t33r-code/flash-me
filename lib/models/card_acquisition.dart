import 'package:cloud_firestore/cloud_firestore.dart';

// Records the provenance of a single card that was copied during a clone
// operation. Stored in cardAcquisitions/{id}.
//
// Primary use: dedup key for re-cloning. If a user clones another set that
// contains the same source card, they get the card they already have rather
// than a new copy.
class CardAcquisition {
  final String id; // Firestore document ID
  final String acquiredByUserId; // cloner uid
  final String originalCardId; // source card document ID
  final String originalCardType; // 'flashcard' | 'workbook'
  final String acquiredCardId; // resulting card in cloner's library
  final DateTime acquiredAt;

  const CardAcquisition({
    required this.id,
    required this.acquiredByUserId,
    required this.originalCardId,
    required this.originalCardType,
    required this.acquiredCardId,
    required this.acquiredAt,
  });

  factory CardAcquisition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CardAcquisition(
      id: doc.id,
      acquiredByUserId: data['acquiredByUserId'] as String,
      originalCardId: data['originalCardId'] as String,
      originalCardType: data['originalCardType'] as String,
      acquiredCardId: data['acquiredCardId'] as String,
      acquiredAt: (data['acquiredAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'acquiredByUserId': acquiredByUserId,
        'originalCardId': originalCardId,
        'originalCardType': originalCardType,
        'acquiredCardId': acquiredCardId,
        'acquiredAt': Timestamp.fromDate(acquiredAt),
      };
}
