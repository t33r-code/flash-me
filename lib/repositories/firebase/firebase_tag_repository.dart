import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/tag.dart';
import 'package:flash_me/repositories/tag_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/helpers.dart';

class FirebaseTagRepository implements TagRepository {
  final FirebaseFirestore _firestore;
  FirebaseTagRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tagsCollection);

  @override
  Future<void> upsertTag(String rawTag, String userId) async {
    final normalized = AppHelpers.normalizeTag(rawTag);
    if (normalized.isEmpty) return;
    final docRef = _col.doc(normalized);

    // Transactional upsert: create on first use (preserves displayName casing),
    // increment on subsequent uses (displayName and createdBy are immutable).
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {
          'normalizedName': normalized,
          'displayName': rawTag.trim(),
          'usageCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
        });
      } else {
        tx.update(docRef, {'usageCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<void> decrementTag(String normalizedTag) async {
    if (normalizedTag.isEmpty) return;
    await _col.doc(normalizedTag).update({
      'usageCount': FieldValue.increment(-1),
    });
  }

  @override
  Stream<List<Tag>> searchTags(String prefix) {
    final normalized = AppHelpers.normalizeTag(prefix);
    if (normalized.isEmpty) return Stream.value([]);

    // U+F8FF is the last codepoint in Unicode's private-use area — appending
    // it gives the exclusive upper bound for a normalizedName prefix query.
    final upperBound = "$normalized";
    return _col
        .where('normalizedName', isGreaterThanOrEqualTo: normalized)
        .where('normalizedName', isLessThan: upperBound)
        .orderBy('normalizedName')
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map(Tag.fromFirestore).toList());
  }
}
