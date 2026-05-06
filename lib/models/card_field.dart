import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// CardFieldContent — sealed class hierarchy
//
// Each field type on a card has a different content shape. Using a sealed
// class lets the compiler enforce exhaustive switch statements when you add
// new types — just add a new subclass and the compiler shows every switch
// that needs updating.
//
// Answer fields (answer, correctAnswers, correctIndex) are nullable so that
// templates can reuse these same models without filling in answers. Config
// fields (options, hint) CAN be pre-filled in templates.
// ---------------------------------------------------------------------------
sealed class CardFieldContent {
  const CardFieldContent();

  // Reconstruct the correct subtype from Firestore/JSON data.
  // [type] is the field type string (AppConstants.fieldType*).
  factory CardFieldContent.fromJson(String type, Map<String, dynamic> json) {
    switch (type) {
      case AppConstants.fieldTypeReveal:
        return RevealContent.fromJson(json);
      case AppConstants.fieldTypeTextInput:
        return TextInputContent.fromJson(json);
      case AppConstants.fieldTypeMultipleChoice:
        return MultipleChoiceContent.fromJson(json);
      default:
        throw ArgumentError('Unknown field type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

// --- Reveal field ----------------------------------------------------------
// Shows a hidden answer that the user clicks to reveal.
class RevealContent extends CardFieldContent {
  final String? answer; // null when stored in a template

  const RevealContent({this.answer});

  factory RevealContent.fromJson(Map<String, dynamic> json) =>
      RevealContent(answer: json['answer'] as String?);

  @override
  Map<String, dynamic> toJson() => {'answer': answer};

  RevealContent copyWith({String? answer}) =>
      RevealContent(answer: answer ?? this.answer);
}

// --- Text input field -------------------------------------------------------
// User types a free-text answer that is checked against correctAnswers.
class TextInputContent extends CardFieldContent {
  final List<String>? correctAnswers; // null in templates; required on cards
  final String? hint; // optional guidance shown to the user
  final bool exactMatch; // false = case-insensitive comparison (default)

  const TextInputContent({
    this.correctAnswers,
    this.hint,
    this.exactMatch = false,
  });

  factory TextInputContent.fromJson(Map<String, dynamic> json) =>
      TextInputContent(
        correctAnswers: json['correctAnswers'] != null
            ? List<String>.from(json['correctAnswers'] as List)
            : null,
        hint: json['hint'] as String?,
        exactMatch: json['exactMatch'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
        'correctAnswers': correctAnswers,
        'hint': hint,
        'exactMatch': exactMatch,
      };

  TextInputContent copyWith({
    List<String>? correctAnswers,
    String? hint,
    bool? exactMatch,
  }) =>
      TextInputContent(
        correctAnswers: correctAnswers ?? this.correctAnswers,
        hint: hint ?? this.hint,
        exactMatch: exactMatch ?? this.exactMatch,
      );
}

// --- Multiple choice field --------------------------------------------------
// User selects from a list of options; one option is correct.
class MultipleChoiceContent extends CardFieldContent {
  final List<String>? options; // CAN be pre-filled in templates
  final int? correctIndex; // index into options; null in templates
  final String? explanation; // optional text shown after answering

  const MultipleChoiceContent({
    this.options,
    this.correctIndex,
    this.explanation,
  });

  factory MultipleChoiceContent.fromJson(Map<String, dynamic> json) =>
      MultipleChoiceContent(
        options: json['options'] != null
            ? List<String>.from(json['options'] as List)
            : null,
        correctIndex: json['correctIndex'] as int?,
        explanation: json['explanation'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  MultipleChoiceContent copyWith({
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) =>
      MultipleChoiceContent(
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        explanation: explanation ?? this.explanation,
      );
}

// ---------------------------------------------------------------------------
// CardField — one field on a card (or template)
// ---------------------------------------------------------------------------
class CardField {
  final String fieldId; // client-generated unique ID (Firestore .doc().id)
  final String name; // label shown to the user, e.g. "Gender"
  final String type; // one of AppConstants.fieldType*
  final CardFieldContent content;

  const CardField({
    required this.fieldId,
    required this.name,
    required this.type,
    required this.content,
  });

  // Deserialise from a Firestore/JSON map (fields are stored as an array of maps).
  factory CardField.fromJson(Map<String, dynamic> json) => CardField(
        fieldId: json['fieldId'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        content: CardFieldContent.fromJson(
          json['type'] as String,
          json['content'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
        'fieldId': fieldId,
        'name': name,
        'type': type,
        'content': content.toJson(),
      };

  // Helper: generate a new fieldId using Firestore's ID generator (no network call).
  static String generateId() =>
      FirebaseFirestore.instance.collection('_').doc().id;

  CardField copyWith({
    String? fieldId,
    String? name,
    String? type,
    CardFieldContent? content,
  }) =>
      CardField(
        fieldId: fieldId ?? this.fieldId,
        name: name ?? this.name,
        type: type ?? this.type,
        content: content ?? this.content,
      );
}
