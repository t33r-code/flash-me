import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_field.dart';

// Represents a single flash card stored in Firestore under cards/{cardId}.
// Set membership is tracked separately in the setCards collection, not here.
class FlashCard {
  final String id; // Firestore document ID
  final String primaryWord; // foreign language word (always present)
  final String translation; // native language translation (always present)
  final String? primaryImageUrl; // optional Firebase Storage URL for a clip-art style image
  final String? primaryAudioUrl; // optional Firebase Storage URL for a pronunciation audio clip
  // When true, primaryWord is hidden on first display and revealed via a "Show Hint" button.
  // Only meaningful when at least one of primaryImageUrl / primaryAudioUrl is set.
  final bool primaryWordHidden;
  final List<CardField> fields; // additional fields (reveal, text input, multiple choice)
  final String? templateId; // optional: which template this card was created from
  final List<String> tags; // user-defined labels for search and filtering in My Cards
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // uid of the owning user

  const FlashCard({
    required this.id,
    required this.primaryWord,
    required this.translation,
    this.primaryImageUrl,
    this.primaryAudioUrl,
    this.primaryWordHidden = false,
    required this.fields,
    this.templateId,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  // Build a FlashCard from a Firestore document snapshot.
  factory FlashCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlashCard(
      id: doc.id,
      primaryWord: data['primaryWord'] as String? ?? '',
      translation: data['translation'] as String? ?? '',
      primaryImageUrl: data['primaryImageUrl'] as String?,
      primaryAudioUrl: data['primaryAudioUrl'] as String?,
      primaryWordHidden: data['primaryWordHidden'] as bool? ?? false,
      // Firestore stores fields as a List of Maps; deserialise each one.
      fields: (data['fields'] as List<dynamic>? ?? [])
          .map((f) => CardField.fromJson(f as Map<String, dynamic>))
          .toList(),
      templateId: data['templateId'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  // Serialise for writing to Firestore. Excludes the document ID.
  Map<String, dynamic> toFirestore() => {
        'primaryWord': primaryWord,
        'translation': translation,
        'primaryImageUrl': primaryImageUrl,
        'primaryAudioUrl': primaryAudioUrl,
        'primaryWordHidden': primaryWordHidden,
        'fields': fields.map((f) => f.toJson()).toList(),
        'templateId': templateId,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
      };

  // Serialise to a plain JSON map (used for ZIP import/export in Phase 6).
  // Media URLs are full Firebase Storage URLs here; the Phase 6 exporter
  // replaces them with relative media/ paths when building the ZIP archive.
  Map<String, dynamic> toJson() => {
        'id': id,
        'primaryWord': primaryWord,
        'translation': translation,
        'primaryImageUrl': primaryImageUrl,
        'primaryAudioUrl': primaryAudioUrl,
        'primaryWordHidden': primaryWordHidden,
        'fields': fields.map((f) => f.toJson()).toList(),
        'templateId': templateId,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
      };

  FlashCard copyWith({
    String? id,
    String? primaryWord,
    String? translation,
    String? primaryImageUrl,
    String? primaryAudioUrl,
    bool? primaryWordHidden,
    List<CardField>? fields,
    String? templateId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) =>
      FlashCard(
        id: id ?? this.id,
        primaryWord: primaryWord ?? this.primaryWord,
        translation: translation ?? this.translation,
        primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
        primaryAudioUrl: primaryAudioUrl ?? this.primaryAudioUrl,
        primaryWordHidden: primaryWordHidden ?? this.primaryWordHidden,
        fields: fields ?? this.fields,
        templateId: templateId ?? this.templateId,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
