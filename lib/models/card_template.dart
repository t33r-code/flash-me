import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_field.dart';

// A reusable field layout stored in Firestore under templates/{templateId}.
//
// Templates use the same CardField model as cards, but answer fields are
// nullable. For example, a "Gender" multiple choice template field stores the
// options list but leaves correctIndex null — the user fills that in per card.
class CardTemplate {
  final String id; // Firestore document ID
  final String createdBy; // uid of the owning user
  final String name; // e.g. "Spanish Verb"
  final String? description;
  // Fields with the same structure as FlashCard.fields; answers are nullable.
  final List<CardField> fields;
  // Whether the primary word should be hidden on first display when media is present.
  // Templates carry this flag as a default for cards created from them.
  // Unlike FlashCard, templates do NOT store media URLs — those are per-card.
  final bool primaryWordHidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CardTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    this.description,
    required this.fields,
    this.primaryWordHidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CardTemplate(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      fields: (data['fields'] as List<dynamic>? ?? [])
          .map((f) => CardField.fromJson(f as Map<String, dynamic>))
          .toList(),
      primaryWordHidden: data['primaryWordHidden'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        'primaryWordHidden': primaryWordHidden,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        'primaryWordHidden': primaryWordHidden,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  CardTemplate copyWith({
    String? id,
    String? createdBy,
    String? name,
    String? description,
    List<CardField>? fields,
    bool? primaryWordHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CardTemplate(
        id: id ?? this.id,
        createdBy: createdBy ?? this.createdBy,
        name: name ?? this.name,
        description: description ?? this.description,
        fields: fields ?? this.fields,
        primaryWordHidden: primaryWordHidden ?? this.primaryWordHidden,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
