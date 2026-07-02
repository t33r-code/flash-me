part of '../import_service.dart';

// ---------------------------------------------------------------------------
// Diffing — compares a parsed set/card against the user's Firestore data and
// produces an ImportSetDiff describing what would be added, updated, or removed.
// ---------------------------------------------------------------------------

// Parse and diff a single raw set map against the user's existing Firestore data.
Future<ImportSetDiff> _diffSet({
  required Map<String, dynamic> rawSet,
  required String userId,
  required CardSetRepository cardSetRepo,
  required CardRepository cardRepo,
  required Map<String, QuestionTemplate> qtMap,
}) async {
  final setName = rawSet['name'] as String? ?? '';
  if (setName.isEmpty) throw AppException('A set in the import has no name.');

  final rawCards = (rawSet['cards'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final importCards =
      rawCards.map((c) => _parseCard(c, qtMap)).toList();

  // Look up existing set and its current cards.
  final existingSet = await cardSetRepo.findSetByName(setName, userId);
  final existingCards = existingSet != null
      ? await cardSetRepo
          .watchCardsInSet(existingSet.id, userId)
          .first
      : <FlashCard>[];

  final existingByWord = {for (final c in existingCards) c.primaryWord: c};
  final importWords = importCards.map((c) => c.primaryWord).toSet();

  final newCards = <NewCardEntry>[];
  final libraryLinkCards = <LibraryLinkEntry>[];
  final updatedCards = <UpdatedCardEntry>[];

  for (final imported in importCards) {
    final existing = existingByWord[imported.primaryWord];
    if (existing == null) {
      // Not in this set — check the global library before creating a new card.
      final libraryCard = await cardRepo.findCardByWordAndTranslation(
        imported.primaryWord,
        imported.translation,
        userId,
      );
      if (libraryCard != null) {
        libraryLinkCards.add(
            LibraryLinkEntry(existingCard: libraryCard, incoming: imported));
      } else {
        newCards.add(NewCardEntry(imported));
      }
    } else {
      final changes = _buildChanges(existing, imported);
      if (changes.isNotEmpty) {
        final affectedSets = await cardSetRepo.getSetsContainingCard(existing.id, userId);
        updatedCards.add(UpdatedCardEntry(
          existing: existing,
          incoming: imported,
          changes: changes,
          affectedSetNames: affectedSets.map((s) => s.name).toList(),
        ));
      }
      // If no fields changed, the card is identical — silently skip.
    }
  }

  final deletableCards = existingCards
      .where((c) => !importWords.contains(c.primaryWord))
      .toList();

  return ImportSetDiff(
    setName: setName,
    existingSet: existingSet,
    newCards: newCards,
    libraryLinkCards: libraryLinkCards,
    updatedCards: updatedCards,
    deletableCards: deletableCards,
  );
}

// Diff each attribute of an existing card against the incoming data and return
// display-ready old→new FieldChange pairs.
List<FieldChange> _buildChanges(FlashCard existing, ImportCardData incoming) {
  final changes = <FieldChange>[];
  if (existing.translation != incoming.translation) {
    changes.add(FieldChange(
      label: 'translation',
      oldValue: existing.translation,
      newValue: incoming.translation,
    ));
  }
  if (existing.primaryWordHidden != incoming.primaryWordHidden) {
    changes.add(FieldChange(
      label: 'word visibility',
      oldValue: existing.primaryWordHidden ? 'hidden' : 'visible',
      newValue: incoming.primaryWordHidden ? 'hidden' : 'visible',
    ));
  }
  if (!_listsEqual(existing.tags, incoming.tags)) {
    changes.add(FieldChange(
      label: 'tags',
      oldValue: existing.tags.isEmpty ? '(none)' : existing.tags.join(', '),
      newValue: incoming.tags.isEmpty ? '(none)' : incoming.tags.join(', '),
    ));
  }
  if (_questionsChanged(existing.questions, incoming.rawFields)) {
    // Match questions by prompt (label) to produce per-question old→new entries.
    final existingByPrompt = {
      for (final q in existing.questions) (q.prompt ?? ''): q,
    };
    final incomingByPrompt = {
      for (final r in incoming.rawFields)
        ((r['prompt'] ?? r['name']) as String? ?? ''): r,
    };
    // Preserve existing order, then append any newly added prompts.
    final allPrompts = [
      ...existing.questions.map((q) => q.prompt ?? ''),
      ...incoming.rawFields
          .map((r) => (r['prompt'] ?? r['name']) as String? ?? '')
          .where((n) => !existingByPrompt.containsKey(n)),
    ];
    for (final prompt in allPrompts) {
      final eq = existingByPrompt[prompt];
      final ir = incomingByPrompt[prompt];
      final eqType = eq != null ? (eq.toJson()['type'] as String) : null;
      if (eq == null) {
        changes.add(FieldChange(
          label: prompt,
          oldValue: '(not present)',
          newValue: _questionContentSummary(ir!),
        ));
      } else if (ir == null) {
        changes.add(FieldChange(
          label: prompt,
          oldValue: _questionContentSummary(eq),
          newValue: '(removed)',
        ));
      } else if (eqType != ir['type'] ||
          jsonEncode(eq.toJson()['content']) != jsonEncode(ir['content'])) {
        changes.add(FieldChange(
          label: prompt,
          oldValue: _questionContentSummary(eq),
          newValue: _questionContentSummary(ir),
        ));
      }
    }
  }
  // Media: compare presence only (URLs differ between accounts).
  if ((existing.primaryImageUrl != null) != (incoming.mediaImagePath != null)) {
    changes.add(FieldChange(
      label: 'image',
      oldValue: existing.primaryImageUrl != null ? 'present' : 'none',
      newValue: incoming.mediaImagePath != null ? 'present' : 'none',
    ));
  }
  if ((existing.primaryAudioUrl != null) != (incoming.mediaAudioPath != null)) {
    changes.add(FieldChange(
      label: 'audio',
      oldValue: existing.primaryAudioUrl != null ? 'present' : 'none',
      newValue: incoming.mediaAudioPath != null ? 'present' : 'none',
    ));
  }
  return changes;
}

// Return a short human-readable summary of a question's answer content.
// Accepts either a typed [CardQuestion] (existing card) or a raw
// [Map<String,dynamic>] (incoming from the ZIP).
String _questionContentSummary(Object question) {
  if (question is CardQuestion) {
    return switch (question) {
      TextInputQuestion q => (q.correctAnswers == null || q.correctAnswers!.isEmpty)
          ? '(any)'
          : q.correctAnswers!.join(' / '),
      MultipleChoiceQuestion q => () {
          final opts = q.options;
          final idx = q.correctIndex;
          if (idx != null && opts != null && idx >= 0 && idx < opts.length) {
            return opts[idx];
          }
          return opts?.join(' / ') ?? '(no options)';
        }(),
      WordOrderQuestion q =>
          q.correctOrder?.join(' → ') ?? '(no order)',
      FillInTheBlanksQuestion q => q.sentence ?? '(no sentence)',
      GridQuestion q => q.cells == null
          ? '(no grid)'
          : '${q.rowCount}×${q.columnCount} grid',
    };
  }
  if (question is Map<String, dynamic>) {
    final type = question['type'] as String? ?? '';
    final content = question['content'] as Map<String, dynamic>? ?? {};
    if (type == AppConstants.fieldTypeTextInput) {
      final answers = (content['correctAnswers'] as List?)?.cast<String>();
      return (answers == null || answers.isEmpty) ? '(any)' : answers.join(' / ');
    }
    if (type == AppConstants.fieldTypeMultipleChoice) {
      final opts = (content['options'] as List?)?.cast<String>();
      final idx = content['correctIndex'] as int?;
      if (idx != null && opts != null && idx >= 0 && idx < opts.length) {
        return opts[idx];
      }
      return opts?.join(' / ') ?? '(no options)';
    }
    if (type == AppConstants.questionTypeWordOrder) {
      final order = (content['correctOrder'] as List?)?.cast<String>();
      return order?.join(' → ') ?? '(no order)';
    }
    if (type == AppConstants.questionTypeFillInBlanks) {
      return content['sentence'] as String? ?? '(no sentence)';
    }
    if (type == AppConstants.questionTypeGrid) {
      final cells = (content['cells'] as List?)?.length ?? 0;
      final cols = content['columnCount'] as int? ?? 0;
      if (cells == 0 || cols == 0) return '(no grid)';
      return '${cells ~/ cols}×$cols grid';
    }
  }
  return '';
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Compare questions by prompt, type, and content. Questions are considered
// equal if all three match positionally (order matters).
bool _questionsChanged(
  List<CardQuestion> existing,
  List<Map<String, dynamic>> incoming,
) {
  if (existing.length != incoming.length) return true;
  for (var i = 0; i < existing.length; i++) {
    final e = existing[i];
    final imp = incoming[i];

    // Normalise the incoming map through the same model before comparing, so
    // both sides are canonical (identical key set, order, and filled
    // defaults). Comparing the raw incoming JSON directly is brittle: it
    // breaks whenever a field is added to a question's toJson (e.g.
    // randomizeOptions) or when the incoming map omits a defaulted key.
    // fromJson also accepts both 'prompt' and legacy 'name' for the prompt.
    final CardQuestion impQuestion;
    try {
      impQuestion =
          CardQuestion.fromJson({...imp, 'questionId': e.questionId});
    } on ArgumentError {
      // Unknown / unsupported incoming question type — treat as a change.
      return true;
    }

    final eJson = e.toJson();
    final impJson = impQuestion.toJson();
    if ((e.prompt ?? '') != (impQuestion.prompt ?? '') ||
        eJson['type'] != impJson['type'] ||
        jsonEncode(eJson['content']) != jsonEncode(impJson['content'])) {
      return true;
    }
  }
  return false;
}