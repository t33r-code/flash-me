import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_field.dart';

// Represents a single flash card stored in Firestore under cards/{cardId}.
// Set membership is tracked separately in the setCards collection, not here.
class FlashCard {
  final String id; // Firestore document ID
  final String primaryWord; // foreign language word
  final String translation; // native language translation
  final List<CardField> fields; // additional fields (reveal, text input, multiple choice)
  final String? templateId; // optional: which template this card was created from
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // uid of the owning user

  const FlashCard({
    required this.id,
    required this.primaryWord,
    required this.translation,
    required this.fields,
    this.templateId,
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
      // Firestore stores fields as a List of Maps; deserialise each one.
      fields: (data['fields'] as List<dynamic>? ?? [])
          .map((f) => CardField.fromJson(f as Map<String, dynamic>))
          .toList(),
      templateId: data['templateId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  // Serialise for writing to Firestore. Excludes the document ID.
  Map<String, dynamic> toFirestore() => {
        'primaryWord': primaryWord,
        'translation': translation,
        'fields': fields.map((f) => f.toJson()).toList(),
        'templateId': templateId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
      };

  // Serialise to a plain JSON map (used for import/export).
  Map<String, dynamic> toJson() => {
        'id': id,
        'primaryWord': primaryWord,
        'translation': translation,
        'fields': fields.map((f) => f.toJson()).toList(),
        'templateId': templateId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
      };

  FlashCard copyWith({
    String? id,
    String? primaryWord,
    String? translation,
    List<CardField>? fields,
    String? templateId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) =>
      FlashCard(
        id: id ?? this.id,
        primaryWord: primaryWord ?? this.primaryWord,
        translation: translation ?? this.translation,
        fields: fields ?? this.fields,
        templateId: templateId ?? this.templateId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
