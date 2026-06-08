import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/import_diff.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/repositories/question_template_repository.dart';
import 'package:flash_me/repositories/tag_repository.dart';
import 'package:flash_me/repositories/template_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/helpers.dart';

// ---------------------------------------------------------------------------
// ImportService — parses a ZIP archive, diffs it against Firestore, and
// executes the user-approved import.
// ---------------------------------------------------------------------------
class ImportService {
  // ── Public API ─────────────────────────────────────────────────────────────

  // Parse [zipBytes], validate, and diff each set against the user's existing
  // Firestore data. Returns an ImportAnalysis ready to show in the preview
  // dialog. Throws [AppException] on unrecoverable parse/validation errors.
  Future<ImportAnalysis> analyze({
    required Uint8List zipBytes,
    required String userId,
    required CardSetRepository cardSetRepo,
    required CardRepository cardRepo,
    required QuestionTemplateRepository questionTemplateRepo,
    required TemplateRepository templateRepo,
  }) async {
    // 1. Decode ZIP.
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw AppException('Not a valid ZIP file.');
    }
    if (archive.length > 50 * 1024 * 1024) {
      throw AppException('Archive exceeds the 50 MB limit.');
    }

    // 2. Locate and parse cards.json.
    final jsonFile = archive.findFile('cards.json');
    if (jsonFile == null) throw AppException('cards.json not found in archive.');
    final rawStr = utf8.decode(jsonFile.content as List<int>);
    // Strip trailing commas before ] or } — invalid in strict JSON but common
    // in hand-authored files (e.g. the last item in an array or object).
    final jsonStr = rawStr.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw AppException('cards.json is not valid JSON.');
    }

    // 3. Parse templates from the JSON (optional — absent in older exports).
    final rawCTs =
        (root['cardTemplates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawQTs =
        (root['questionTemplates'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // 4. Load existing user templates; determine which JSON templates are new.
    final existingQTs = await questionTemplateRepo.getUserTemplates(userId);
    final existingQTByImportId = <String, QuestionTemplate>{
      for (final t in existingQTs)
        if (t.templateId != null) t.templateId!: t,
    };
    final existingQTByName = {for (final t in existingQTs) t.name: t};

    final existingCTs =
        await templateRepo.watchUserTemplates(userId).first;
    final existingCTNames = {for (final t in existingCTs) t.name};

    // New QTs: not matched by Import ID (if present) or by name.
    final newQTs = <Map<String, dynamic>>[];
    for (final rawQt in rawQTs) {
      final importId = rawQt['templateId'] as String?;
      final name = rawQt['name'] as String? ?? '';
      final exists = importId != null
          ? existingQTByImportId.containsKey(importId)
          : existingQTByName.containsKey(name);
      if (!exists) newQTs.add(rawQt);
    }

    // New CTs: not matched by name.
    final newCTs = rawCTs
        .where((ct) => !existingCTNames.contains(ct['name'] as String? ?? ''))
        .toList();

    // 5. Build QT lookup map: existing DB templates + new JSON-defined ones.
    // JSON-defined QTs are added so ##templateId refs in this file resolve even
    // before execute() creates them in Firestore.
    final qtMap = <String, QuestionTemplate>{
      ...existingQTByImportId,
    };
    for (final rawQt in rawQTs) {
      final importId = rawQt['templateId'] as String?;
      if (importId == null || qtMap.containsKey(importId)) continue;
      final rawQuestion = rawQt['question'] as Map<String, dynamic>?;
      if (rawQuestion == null) continue;
      try {
        final q = CardQuestion.fromJson(
            {...rawQuestion, 'questionId': CardQuestion.generateId()});
        qtMap[importId] = QuestionTemplate(
          id: '',
          createdBy: userId,
          name: rawQt['name'] as String? ?? '',
          description: rawQt['description'] as String?,
          question: q,
          templateId: importId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } on ArgumentError {
        // Skip malformed question types — they'll fail again at execute time.
      }
    }

    // 6. Normalise to a list of raw set maps (supports both formats).
    final List<Map<String, dynamic>> rawSets;
    if (root.containsKey('sets')) {
      rawSets = (root['sets'] as List).cast<Map<String, dynamic>>();
    } else if (root.containsKey('set')) {
      rawSets = [root['set'] as Map<String, dynamic>];
    } else {
      throw AppException(
          'Invalid format: expected a "set" or "sets" key in cards.json.');
    }

    // 7. Parse, validate, and diff each set.
    final diffs = <ImportSetDiff>[];
    for (final rawSet in rawSets) {
      final diff = await _diffSet(
        rawSet: rawSet,
        userId: userId,
        cardSetRepo: cardSetRepo,
        cardRepo: cardRepo,
        qtMap: qtMap,
      );
      diffs.add(diff);
    }

    return ImportAnalysis(
      setDiffs: diffs,
      archive: archive,
      newCardTemplates: newCTs,
      newQuestionTemplates: newQTs,
    );
  }

  // Execute the import based on the user's choices.
  // [analysis] must be the value returned by the most recent analyze() call.
  Future<void> execute({
    required ImportAnalysis analysis,
    required bool deleteNotInImport,
    required bool skipUpdates,
    required String userId,
    required CardSetRepository cardSetRepo,
    required CardRepository cardRepo,
    required TemplateRepository templateRepo,
    required QuestionTemplateRepository questionTemplateRepo,
    required TagRepository tagRepo,
  }) async {
    // Create new Question Templates first so they exist for future imports.
    for (final rawQt in analysis.newQuestionTemplates) {
      await _createQuestionTemplate(rawQt, userId, questionTemplateRepo);
    }
    // Create new Card Templates.
    for (final rawCt in analysis.newCardTemplates) {
      await _createCardTemplate(rawCt, userId, templateRepo);
    }

    for (final diff in analysis.setDiffs) {
      // Resolve (or create) the set.
      final targetSet = diff.existingSet ??
          await cardSetRepo.createSet(CardSet(
            id: '',
            userId: userId,
            name: diff.setName,
            cardCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));

      // Create new cards.
      for (final entry in diff.newCards) {
        final imageUrl = await _uploadMedia(
            analysis.archive, entry.data.mediaImagePath, userId);
        final audioUrl = await _uploadMedia(
            analysis.archive, entry.data.mediaAudioPath, userId);
        final card = await cardRepo.createCard(FlashCard(
          id: '',
          primaryWord: entry.data.primaryWord,
          translation: entry.data.translation,
          primaryWordHidden: entry.data.primaryWordHidden,
          primaryImageUrl: imageUrl,
          primaryAudioUrl: audioUrl,
          questions: _buildQuestions(entry.data.rawFields),
          templateId: entry.data.templateId,
          tags: entry.data.tags,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        ));
        await cardSetRepo.addCardToSet(
          setId: targetSet.id,
          cardId: card.id,
          userId: userId,
        );
        for (final tag in entry.data.tags) { tagRepo.upsertTag(tag, userId); }
      }

      // Link library cards to the set — no card creation needed.
      for (final entry in diff.libraryLinkCards) {
        await cardSetRepo.addCardToSet(
          setId: targetSet.id,
          cardId: entry.existingCard.id,
          userId: userId,
        );
      }

      // Update existing cards (unless the user opted to skip updates).
      if (!skipUpdates) {
        for (final entry in diff.updatedCards) {
          final imageUrl = entry.incoming.mediaImagePath != null
              ? await _uploadMedia(
                  analysis.archive, entry.incoming.mediaImagePath, userId)
              : entry.existing.primaryImageUrl;
          final audioUrl = entry.incoming.mediaAudioPath != null
              ? await _uploadMedia(
                  analysis.archive, entry.incoming.mediaAudioPath, userId)
              : entry.existing.primaryAudioUrl;
          final (toUpsert, toDecrement) =
              AppHelpers.diffTags(entry.existing.tags, entry.incoming.tags);
          await cardRepo.updateCard(entry.existing.copyWith(
            translation: entry.incoming.translation,
            primaryWordHidden: entry.incoming.primaryWordHidden,
            primaryImageUrl: imageUrl,
            primaryAudioUrl: audioUrl,
            questions: _buildQuestions(entry.incoming.rawFields),
            templateId: entry.incoming.templateId,
            tags: entry.incoming.tags,
            updatedAt: DateTime.now(),
          ));
          for (final tag in toUpsert) { tagRepo.upsertTag(tag, userId); }
          for (final norm in toDecrement) { tagRepo.decrementTag(norm); }
        }
      }

      // Remove set-membership links for cards not in the import file.
      // The cards themselves are NOT deleted — they remain in the user's
      // card library and any other sets they belong to.
      if (deleteNotInImport) {
        for (final card in diff.deletableCards) {
          await cardSetRepo.removeCardFromSet(
            setId: targetSet.id,
            cardId: card.id,
            userId: userId,
          );
        }
      }
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

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

  ImportCardData _parseCard(
      Map<String, dynamic> raw, Map<String, QuestionTemplate> qtMap) {
    final word = raw['primaryWord'] as String? ?? '';
    final translation = raw['translation'] as String? ?? '';
    if (word.isEmpty) throw AppException('A card is missing primaryWord.');
    if (translation.isEmpty) {
      throw AppException('Card "$word" is missing translation.');
    }

    // Accept both 'questions' (new format) and 'fields' (legacy ZIP export).
    final rawFields = ((raw['questions'] ?? raw['fields']) as List? ?? [])
        .cast<Map<String, dynamic>>();

    // Validate and resolve each question entry.
    // Template references ("template": "##id") are expanded here so that all
    // downstream code (diff, build) sees standard question maps.
    final resolvedFields = <Map<String, dynamic>>[];
    for (final f in rawFields) {
      if (_isTemplateRef(f)) {
        // ##id reference — look up in the user's question templates.
        final refValue = f['template'] as String;
        final refId = refValue.substring(kTemplateIdPrefix.length);
        final qt = qtMap[refId];
        if (qt == null) {
          throw AppException(
            'Card "$word" references unknown question template '
            '"$refValue". Create this question template before importing.',
          );
        }
        resolvedFields.add(_resolveTemplateRef(qt, f));
      } else {
        // Standard question entry — name/prompt interchangeable; content required.
        if ((f['name'] == null && f['prompt'] == null) ||
            f['type'] == null ||
            f['content'] == null) {
          throw AppException('Card "$word" has a malformed question entry.');
        }
        resolvedFields.add(f);
      }
    }

    return ImportCardData(
      primaryWord: word,
      translation: translation,
      primaryWordHidden: raw['primaryWordHidden'] as bool? ?? false,
      mediaImagePath: raw['primaryImageUrl'] as String?,
      mediaAudioPath: raw['primaryAudioUrl'] as String?,
      rawFields: resolvedFields,
      templateId: raw['templateId'] as String?,
      tags: List<String>.from(raw['tags'] as List? ?? []),
    );
  }

  // Returns true when a raw question map is a ##templateId reference.
  bool _isTemplateRef(Map<String, dynamic> f) {
    final t = f['template'];
    return t is String && t.startsWith(kTemplateIdPrefix);
  }

  // Expand a ##templateId reference into a standard question map by merging
  // the template's question structure with any answer overrides in [ref].
  Map<String, dynamic> _resolveTemplateRef(
      QuestionTemplate qt, Map<String, dynamic> ref) {
    final qJson = Map<String, dynamic>.from(qt.question.toJson());
    qJson.remove('questionId'); // fresh ID is generated by _buildQuestions

    // Merge answer-field overrides from the ref entry into the content map.
    final content =
        Map<String, dynamic>.from(qJson['content'] as Map<String, dynamic>? ?? {});
    for (final key in ['correctIndex', 'correctAnswers', 'correctOrder', 'wordBank']) {
      if (ref.containsKey(key)) content[key] = ref[key];
    }
    qJson['content'] = content;
    return qJson;
  }

  // Diff each attribute and return display-ready old→new pairs.
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
      final eJson = e.toJson();
      final ePrompt = e.prompt ?? '';
      final impPrompt = (imp['prompt'] ?? imp['name']) as String? ?? '';
      if (ePrompt != impPrompt ||
          eJson['type'] != imp['type'] ||
          jsonEncode(eJson['content']) != jsonEncode(imp['content'])) {
        return true;
      }
    }
    return false;
  }

  // Build a CardQuestion list from raw ZIP JSON maps, generating fresh IDs.
  // Unknown types (e.g. legacy 'reveal') are silently skipped.
  List<CardQuestion> _buildQuestions(List<Map<String, dynamic>> rawFields) {
    final questions = <CardQuestion>[];
    for (final f in rawFields) {
      try {
        questions.add(CardQuestion.fromJson({
          ...f,
          'questionId': CardQuestion.generateId(),
        }));
      } on ArgumentError {
        // skip unsupported types
      }
    }
    return questions;
  }

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

  // Upload a media file from the archive to Firebase Storage.
  // Returns the storage URL, or null if [path] is null or the file is missing.
  Future<String?> _uploadMedia(
    Archive archive,
    String? path,
    String userId,
  ) async {
    if (path == null) return null;
    final file = archive.findFile(path);
    if (file == null) return null;

    final bytes = Uint8List.fromList(file.content as List<int>);
    final ext = path.contains('.') ? path.split('.').last : '';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$userId/cards/$fileName');

    final contentType = _contentType(ext);
    final metadata =
        contentType != null ? SettableMetadata(contentType: contentType) : null;
    final task = metadata != null
        ? ref.putData(bytes, metadata)
        : ref.putData(bytes);
    await task;
    return await ref.getDownloadURL();
  }

  String? _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      default:
        return null;
    }
  }
}
