import 'package:flash_me/models/question_result.dart';

// Provider-agnostic contract for persisting per-field question results.
abstract class QuestionResultRepository {
  // Records a single success/fail outcome for a field, prepending it to the
  // rolling window and trimming to questionResultsWindowSize.
  // Creates the document with defaultResults if it doesn't exist yet.
  Future<void> recordResult({
    required String userId,
    required String cardId,
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required String outcome, // AppConstants.resultSuccess | resultFail
  });

  // Streams all question results for a user — used by future filtered study modes.
  Stream<List<QuestionResult>> watchResults(String userId);

  // Returns all results for a single card across all its fields.
  Future<List<QuestionResult>> getResultsForCard(String userId, String cardId);
}
