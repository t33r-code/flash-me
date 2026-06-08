import 'package:cloud_firestore/cloud_firestore.dart';

// A tag document from the global tags/{normalizedName} collection.
// Shared across all users; usageCount tracks total references in cards and sets.
class Tag {
  final String normalizedName; // document ID — lowercase, hyphens, no spaces
  final String displayName;    // original casing from the user who coined the tag
  final int usageCount;        // total references across all cards and sets
  final String createdBy;      // uid of the user who first coined the tag

  const Tag({
    required this.normalizedName,
    required this.displayName,
    required this.usageCount,
    required this.createdBy,
  });

  factory Tag.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tag(
      normalizedName: doc.id,
      displayName: data['displayName'] as String? ?? doc.id,
      usageCount: data['usageCount'] as int? ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}
