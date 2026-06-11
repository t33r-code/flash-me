import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/feedback_item.dart';
import 'package:flash_me/repositories/feedback_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

class FirebaseFeedbackRepository implements FeedbackRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<void> submit(FeedbackItem item) async {
    try {
      await _db
          .collection(AppConstants.feedbackCollection)
          .add(item.toFirestore());
    } catch (e) {
      throw AppException('Failed to submit feedback: $e',
          code: 'feedback-submit-error');
    }
  }
}
