import 'package:cloud_firestore/cloud_firestore.dart';

// Whether the user is reporting a general observation or a specific problem.
enum FeedbackType { feedback, issue }

class FeedbackItem {
  final String userId;
  final String userEmail;
  final String displayName;
  final String context; // HelpContext.name — the screen it was submitted from
  final FeedbackType type;
  final String subject;
  final String body;
  final String platform;
  final DateTime timestamp;
  final String? logs;
  final String status; // 'new' — reserved for future triage workflow

  const FeedbackItem({
    required this.userId,
    required this.userEmail,
    required this.displayName,
    required this.context,
    required this.type,
    required this.subject,
    required this.body,
    required this.platform,
    required this.timestamp,
    this.logs,
    this.status = 'new',
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'userEmail': userEmail,
        'displayName': displayName,
        'context': context,
        'type': type.name,
        'subject': subject,
        'body': body,
        'platform': platform,
        'timestamp': Timestamp.fromDate(timestamp),
        if (logs != null) 'logs': logs,
        'status': status,
      };
}
