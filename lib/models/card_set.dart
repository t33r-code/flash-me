import 'package:cloud_firestore/cloud_firestore.dart';

// A named collection of flash cards, stored in Firestore under sets/{setId}.
// Actual card membership is tracked in the setCards join collection, not here.
// cardCount is denormalized here for cheap display (avoids counting setCards).
class CardSet {
  final String id; // Firestore document ID
  final String userId; // uid of the owning user
  final String name; // e.g. "Spanish Verbs"
  final String? description; // markdown-formatted text; rendered with flutter_markdown
  final int cardCount; // denormalized: kept in sync by CardSetService
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic; // reserved for future sharing features
  final List<String> tags; // optional labels, e.g. ["verbs", "beginner"]
  final String? color; // optional hex color for UI differentiation
  final String? nativeLanguage; // ISO 639-1 code for the user's native language
  final String? targetLanguage; // ISO 639-1 code for the language being studied

  const CardSet({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.cardCount,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
    this.tags = const [],
    this.color,
    this.nativeLanguage,
    this.targetLanguage,
  });

  factory CardSet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CardSet(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      cardCount: data['cardCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isPublic: data['isPublic'] as bool? ?? false,
      tags: List<String>.from(data['tags'] as List? ?? []),
      color: data['color'] as String?,
      nativeLanguage: data['nativeLanguage'] as String?,
      targetLanguage: data['targetLanguage'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'description': description,
        'cardCount': cardCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isPublic': isPublic,
        'tags': tags,
        'color': color,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'description': description,
        'cardCount': cardCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPublic': isPublic,
        'tags': tags,
        'color': color,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
      };

  CardSet copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? cardCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    List<String>? tags,
    String? color,
    String? nativeLanguage,
    String? targetLanguage,
  }) =>
      CardSet(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        description: description ?? this.description,
        cardCount: cardCount ?? this.cardCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isPublic: isPublic ?? this.isPublic,
        tags: tags ?? this.tags,
        color: color ?? this.color,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        targetLanguage: targetLanguage ?? this.targetLanguage,
      );
}
