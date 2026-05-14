import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// Tracks the last N results for a single interactive field on a card.
// Stored at users/{uid}/questionResults/{cardId}_{fieldId}.
//
// results[0] is the most recent outcome; results[4] is the oldest.
// New results push older ones towards the end and drop off at index 5.
class QuestionResult {
  final String cardId;
  final String fieldId;
  final String fieldName;  // display label, e.g. "Gender"
  final String fieldType;  // AppConstants.fieldTypeTextInput / fieldTypeMultipleChoice
  final List<String> results; // 'success' | 'fail' | 'unseen'
  final DateTime updatedAt;

  const QuestionResult({
    required this.cardId,
    required this.fieldId,
    required this.fieldName,
    required this.fieldType,
    required this.results,
    required this.updatedAt,
  });

  // Document ID used in Firestore: cardId + fieldId joined with underscore.
  static String docId(String cardId, String fieldId) => '${cardId}_$fieldId';

  // Default results list: all unseen.
  static List<String> get defaultResults =>
      List.filled(AppConstants.questionResultsWindowSize, AppConstants.resultUnseen);

  factory QuestionResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionResult(
      cardId: data['cardId'] as String,
      fieldId: data['fieldId'] as String,
      fieldName: data['fieldName'] as String,
      fieldType: data['fieldType'] as String,
      results: List<String>.from(data['results'] as List),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'cardId': cardId,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'fieldType': fieldType,
        'results': results,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  // Returns a new QuestionResult with [outcome] prepended and the window trimmed to size.
  QuestionResult withNewResult(String outcome) {
    final updated = [outcome, ...results]
        .take(AppConstants.questionResultsWindowSize)
        .toList();
    return QuestionResult(
      cardId: cardId,
      fieldId: fieldId,
      fieldName: fieldName,
      fieldType: fieldType,
      results: updated,
      updatedAt: DateTime.now(),
    );
  }
}
