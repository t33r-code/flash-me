import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_question.dart';

// Represents a single flash card stored in Firestore under cards/{cardId}.
// Set membership is tracked separately in the setCards collection, not here.
class FlashCard {
  final String id; // Firestore document ID
  final String primaryWord;        // foreign language word (always present)
  final String translation;        // native language translation (always present)
  final String? primaryImageUrl;   // optional Firebase Storage URL for a clip-art style image
  final String? primaryAudioUrl;   // optional Firebase Storage URL for a pronunciation audio clip
  // When true, primaryWord is hidden on first display and revealed via a "Show Hint" button.
  // Only meaningful when at least one of primaryImageUrl / primaryAudioUrl is set.
  final bool primaryWordHidden;
  // Additional interactive questions attached to this card (text input, MC, word order).
  // Stored as 'questions' in Firestore; legacy docs may use 'fields' (handled in fromFirestore).
  final List<CardQuestion> questions;
  final String? templateId;        // optional: which template this card was created from
  final List<String> tags;         // user-defined labels for search and filtering in My Cards
  final String? nativeLanguage;    // ISO 639-1 code for the user's native language, e.g. 'en'
  final String? targetLanguage;    // ISO 639-1 code for the language being studied, e.g. 'es'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;          // uid of the owning user

  const FlashCard({
    required this.id,
    required this.primaryWord,
    required this.translation,
    this.primaryImageUrl,
    this.primaryAudioUrl,
    this.primaryWordHidden = false,
    required this.questions,
    this.templateId,
    this.tags = const [],
    this.nativeLanguage,
    this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  // Build a FlashCard from a Firestore document snapshot.
  // Reads 'questions' first; falls back to legacy 'fields' key for pre-migration docs.
  // Unknown question types (e.g. legacy 'reveal') are silently dropped.
  factory FlashCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawQuestions =
        (data['questions'] ?? data['fields']) as List<dynamic>? ?? [];
    final questions = rawQuestions
        .map((q) {
          try {
            return CardQuestion.fromJson(q as Map<String, dynamic>);
          } on ArgumentError {
            return null; // skip unsupported types (e.g. legacy 'reveal')
          }
        })
        .whereType<CardQuestion>()
        .toList();

    return FlashCard(
      id: doc.id,
      primaryWord: data['primaryWord'] as String? ?? '',
      translation: data['translation'] as String? ?? '',
      primaryImageUrl: data['primaryImageUrl'] as String?,
      primaryAudioUrl: data['primaryAudioUrl'] as String?,
      primaryWordHidden: data['primaryWordHidden'] as bool? ?? false,
      questions: questions,
      templateId: data['templateId'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      nativeLanguage: data['nativeLanguage'] as String?,
      targetLanguage: data['targetLanguage'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  // Serialise for writing to Firestore. Uses the new 'questions' key.
  Map<String, dynamic> toFirestore() => {
        'primaryWord': primaryWord,
        'translation': translation,
        'primaryImageUrl': primaryImageUrl,
        'primaryAudioUrl': primaryAudioUrl,
        'primaryWordHidden': primaryWordHidden,
        'questions': questions.map((q) => q.toJson()).toList(),
        'templateId': templateId,
        'tags': tags,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
      };

  // Serialise to a plain JSON map (used for ZIP import/export in Phase 6).
  Map<String, dynamic> toJson() => {
        'id': id,
        'primaryWord': primaryWord,
        'translation': translation,
        'primaryImageUrl': primaryImageUrl,
        'primaryAudioUrl': primaryAudioUrl,
        'primaryWordHidden': primaryWordHidden,
        'questions': questions.map((q) => q.toJson()).toList(),
        'templateId': templateId,
        'tags': tags,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
      };

  // Returns validation errors for user-entered fields; empty list means safe to save.
  List<String> validate() {
    final errors = <String>[];
    if (primaryWord.trim().isEmpty) errors.add('primary word is required');
    if (translation.trim().isEmpty) errors.add('translation is required');
    for (var i = 0; i < questions.length; i++) {
      for (final e in questions[i].validate()) {
        errors.add('question ${i + 1}: $e');
      }
    }
    return errors;
  }

  FlashCard copyWith({
    String? id,
    String? primaryWord,
    String? translation,
    String? primaryImageUrl,
    String? primaryAudioUrl,
    bool? primaryWordHidden,
    List<CardQuestion>? questions,
    String? templateId,
    List<String>? tags,
    String? nativeLanguage,
    String? targetLanguage,
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
        questions: questions ?? this.questions,
        templateId: templateId ?? this.templateId,
        tags: tags ?? this.tags,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
