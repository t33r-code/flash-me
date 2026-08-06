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
import 'package:flash_me/utils/import_media_validation.dart';

part 'import/import_parse.dart';
part 'import/import_diff.dart';
part 'import/import_media.dart';
part 'import/import_templates.dart';

// ---------------------------------------------------------------------------
// ImportService — parses a ZIP archive, diffs it against Firestore, and
// executes the user-approved import.
//
// Private helpers are split across four part files:
//   import/import_parse.dart     — card JSON → ImportCardData
//   import/import_diff.dart      — ImportCardData ↔ Firestore diff
//   import/import_media.dart     — archive file → Firebase Storage
//   import/import_templates.dart — raw JSON → CardTemplate / QuestionTemplate
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
    try {
      return await _analyze(
        zipBytes: zipBytes,
        userId: userId,
        cardSetRepo: cardSetRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );
    } on TypeError {
      // Safety net for wrong-typed JSON (#300 F3). _asObjectList and the
      // structural checks below give precise messages for the common shape
      // mistakes; this catches the long tail of `as` / `.cast<T>()` on
      // untrusted values across _diffSet and _parseCard, which would otherwise
      // escape as an unhandled TypeError. Deliberately narrow — AppException
      // and genuine I/O errors still propagate unchanged.
      throw AppException(
          'cards.json has unexpected data types. Please check the file format.');
    }
  }

  Future<ImportAnalysis> _analyze({
    required Uint8List zipBytes,
    required String userId,
    required CardSetRepository cardSetRepo,
    required CardRepository cardRepo,
    required QuestionTemplateRepository questionTemplateRepo,
    required TemplateRepository templateRepo,
  }) async {
    // 1. Decode ZIP.
    // Bound the raw input first: decodeBytes and every `.content` read below
    // inflate into memory. Deliberately outside the try/catch — an
    // AppException thrown inside it would be swallowed and remapped to
    // 'Not a valid ZIP file.', which is the wrong diagnosis.
    if (zipBytes.length > AppConstants.maxImportArchiveBytes) {
      throw AppException('Archive exceeds the 50 MB limit.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw AppException('Not a valid ZIP file.');
    }

    // A small archive can still declare gigabytes of uncompressed content, so
    // check the inflated total before reading any entry. This previously read
    // `archive.length`, which is the entry *count*, not a byte size — so it
    // compared a handful of entries against ~52 million and could never fire
    // (#298). Entries are read via `.content` here and in _uploadMedia during
    // execute(), which only runs on the ImportAnalysis produced below — so
    // this one check covers both paths.
    final uncompressedBytes =
        archive.files.fold<int>(0, (sum, f) => sum + f.size);
    if (uncompressedBytes > AppConstants.maxImportArchiveBytes) {
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
    final rawCTs = _asObjectList(root['cardTemplates'], 'cardTemplates');
    final rawQTs = _asObjectList(root['questionTemplates'], 'questionTemplates');

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
      rawSets = _asObjectList(root['sets'], 'sets');
    } else if (root.containsKey('set')) {
      final rawSet = root['set'];
      if (rawSet is! Map<String, dynamic>) {
        throw AppException('Invalid format: "set" must be an object.');
      }
      rawSets = [rawSet];
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
      mediaIssues: _collectMediaIssues(archive, diffs),
    );
  }

  // Pre-flight every media entry the import would upload, so a file Storage is
  // certain to refuse is surfaced in the preview instead of aborting execute()
  // after cards have already been written (#330).
  //
  // Only newCards and updatedCards are checked: libraryLinkCards match an
  // existing card and are linked, not re-uploaded. Entries missing from the
  // archive are skipped — _uploadMedia already tolerates those by returning
  // null, so reporting them as a rules problem would be a wrong diagnosis.
  List<MediaIssue> _collectMediaIssues(
      Archive archive, List<ImportSetDiff> diffs) {
    final issues = <String, MediaIssue>{}; // keyed by path, so shared media
    // referenced by several cards is reported once.
    void check(String? path) {
      if (path == null || issues.containsKey(path)) return;
      final file = archive.findFile(path);
      if (file == null) return;
      final issue = validateImportMedia(path: path, sizeBytes: file.size);
      if (issue != null) issues[path] = issue;
    }

    for (final diff in diffs) {
      for (final entry in diff.newCards) {
        check(entry.data.mediaImagePath);
        check(entry.data.mediaAudioPath);
      }
      for (final entry in diff.updatedCards) {
        check(entry.incoming.mediaImagePath);
        check(entry.incoming.mediaAudioPath);
      }
    }
    return issues.values.toList();
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
}