import 'package:cloud_firestore/cloud_firestore.dart';

// Records a single acquisition event in the setAcquisitions/{id} collection.
// Covers clone now; extensible to subscription/purchase via acquisitionType.
class SetAcquisition {
  final String id; // Firestore document ID
  final String acquiredByUserId; // user who performed the acquisition
  final String originalSetId; // the market set (source of truth)
  final String originalUserId; // creator of the market set
  final String acquiredSetId; // the resulting copy in the acquirer's library
  final String acquisitionType; // 'clone' | 'subscription' (extensible)
  final DateTime acquiredAt;

  const SetAcquisition({
    required this.id,
    required this.acquiredByUserId,
    required this.originalSetId,
    required this.originalUserId,
    required this.acquiredSetId,
    this.acquisitionType = 'clone',
    required this.acquiredAt,
  });

  factory SetAcquisition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SetAcquisition(
      id: doc.id,
      acquiredByUserId: data['acquiredByUserId'] as String,
      originalSetId: data['originalSetId'] as String,
      originalUserId: data['originalUserId'] as String,
      acquiredSetId: data['acquiredSetId'] as String,
      acquisitionType: data['acquisitionType'] as String? ?? 'clone',
      acquiredAt: (data['acquiredAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'acquiredByUserId': acquiredByUserId,
        'originalSetId': originalSetId,
        'originalUserId': originalUserId,
        'acquiredSetId': acquiredSetId,
        'acquisitionType': acquisitionType,
        'acquiredAt': Timestamp.fromDate(acquiredAt),
      };
}
