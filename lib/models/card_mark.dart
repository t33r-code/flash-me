import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a user's persistent Skip / Review mark on a single card.
// Stored as users/{userId}/cardMarks/{cardId} so cardId is the document ID.
class CardMark {
  final String cardId;
  final String mark; // AppConstants.markSkip | AppConstants.markReview
  final DateTime markedAt;  // timestamp of the first mark on this card
  final DateTime updatedAt; // timestamp of the most recent change

  const CardMark({
    required this.cardId,
    required this.mark,
    required this.markedAt,
    required this.updatedAt,
  });

  factory CardMark.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CardMark(
      cardId: doc.id,
      mark: data['mark'] as String,
      markedAt: (data['markedAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'mark': mark,
        'markedAt': Timestamp.fromDate(markedAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
