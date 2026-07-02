part of '../import_service.dart';

// ---------------------------------------------------------------------------
// Template creation — create new CardTemplates and QuestionTemplates from the
// raw JSON maps that were identified as new during analysis.
// ---------------------------------------------------------------------------

// Create a QuestionTemplate from a raw JSON map (as exported by ExportService).
// Silently skips entries with missing name or unrecognised question types.
Future<void> _createQuestionTemplate(
  Map<String, dynamic> raw,
  String userId,
  QuestionTemplateRepository repo,
) async {
  final name = raw['name'] as String? ?? '';
  if (name.isEmpty) return;
  final rawQuestion = raw['question'] as Map<String, dynamic>?;
  if (rawQuestion == null) return;
  try {
    final question = CardQuestion.fromJson(
        {...rawQuestion, 'questionId': CardQuestion.generateId()});
    await repo.createTemplate(QuestionTemplate(
      id: '',
      createdBy: userId,
      name: name,
      description: raw['description'] as String?,
      question: question,
      templateId: raw['templateId'] as String?,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  } on ArgumentError {
    // Unknown question type — skip.
  }
}

// Create a CardTemplate from a raw JSON map (as exported by ExportService).
// Silently skips entries with missing name; unknown question types are dropped.
Future<void> _createCardTemplate(
  Map<String, dynamic> raw,
  String userId,
  TemplateRepository repo,
) async {
  final name = raw['name'] as String? ?? '';
  if (name.isEmpty) return;
  final rawQuestions =
      (raw['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final questions = rawQuestions
      .map((q) {
        try {
          return CardQuestion.fromJson(
              {...q, 'questionId': CardQuestion.generateId()});
        } on ArgumentError {
          return null;
        }
      })
      .whereType<CardQuestion>()
      .toList();
  await repo.createTemplate(CardTemplate(
    id: '',
    createdBy: userId,
    name: name,
    description: raw['description'] as String?,
    questions: questions,
    primaryWordHidden: raw['primaryWordHidden'] as bool? ?? false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));
}