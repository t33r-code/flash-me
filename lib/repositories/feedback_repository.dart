import 'package:flash_me/models/feedback_item.dart';

abstract class FeedbackRepository {
  // Write a feedback/issue submission to the store. Fire-and-forget safe —
  // throws AppException on failure so the caller can surface a SnackBar.
  Future<void> submit(FeedbackItem item);
}
