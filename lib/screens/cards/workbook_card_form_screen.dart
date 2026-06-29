import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/language_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/language_picker.dart';
import 'package:flash_me/widgets/tag_input_field.dart';

// ---------------------------------------------------------------------------
// _QuestionState — mutable holder for one workbook question while the form
// is open.  Mirrors _FieldState in card_form_screen.dart.
//
// Holds controllers for every possible question type so that input survives
// the type-switcher (e.g. typing answers, switching type and back).
// ---------------------------------------------------------------------------
class _QuestionState {
  final String questionId;
  String type; // AppConstants.fieldType* or questionTypeWordOrder
  final TextEditingController promptController; // optional per-question label
  // text_input
  final TextEditingController answersController; // comma-separated
  final TextEditingController hintController;
  bool exactMatch;
  // multiple_choice
  final List<TextEditingController> optionControllers;
  int? correctIndex;
  MultipleChoiceDisplayMode displayMode;
  final TextEditingController explanationController;
  // word_order
  final List<String> wordBank;
  final List<String> correctOrder;
  final TextEditingController wordBankInputController;
  final TextEditingController correctOrderInputController;
  // Keeps the word-bank field focused after each add, like the distractor field.
  final FocusNode wordBankFocus = FocusNode();
  // fill_in_blanks (#170) — field-initialised so the existing constructor call
  // sites don't all need new params; only the fill-in-blanks paths touch these.
  final TextEditingController fibSentenceController = TextEditingController();
  List<FillBlankToken> fibTokens = []; // empty until the author taps Tokenize
  int fibBlankCount = 1;
  final List<String> fibExtraWords = []; // author-added distractor words
  final TextEditingController fibExtraWordInputController =
      TextEditingController();
  // Keeps the distractor field focused after each add (Enter or the Add button)
  // so multiple words can be entered in a row, especially on desktop.
  final FocusNode fibExtraWordFocus = FocusNode();
  // grid (#167) — a 2D list of controllers; steppers resize it in place,
  // preserving already-typed values. Header controllers are separate lists.
  final List<List<TextEditingController>> gridCells = [];
  final List<TextEditingController> gridRowHeaderCtls = [];
  final List<TextEditingController> gridColHeaderCtls = [];
  // Title for the row-header column, shown in the top-left corner (e.g.
  // "Pronoun"); only meaningful when both row and column headers are on.
  final TextEditingController gridCornerCtl = TextEditingController();
  bool gridHasRowHeaders = false;
  bool gridHasColHeaders = false;
  int gridEmptyCount = 1;
  final List<String> gridExtraWords = []; // author-added distractor words
  final TextEditingController gridExtraWordInputController =
      TextEditingController();
  final FocusNode gridExtraWordFocus = FocusNode();
  // Completion mode shared across FIB and Grid — stored per-question so each
  // question on a card can independently be pill or text-input.
  CompletionMode completionMode = CompletionMode.pill;

  _QuestionState({
    required this.questionId,
    required this.type,
    required this.promptController,
    required this.answersController,
    required this.hintController,
    this.exactMatch = false,
    required this.optionControllers,
    this.correctIndex,
    this.displayMode = MultipleChoiceDisplayMode.list,
    required this.explanationController,
    required this.wordBank,
    required this.correctOrder,
    required this.wordBankInputController,
    required this.correctOrderInputController,
  });

  // Blank question defaulting to text_input type.
  factory _QuestionState.empty() => _QuestionState(
        questionId: CardQuestion.generateId(),
        type: AppConstants.fieldTypeTextInput,
        promptController: TextEditingController(),
        answersController: TextEditingController(),
        hintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
        explanationController: TextEditingController(),
        wordBank: [],
        correctOrder: [],
        wordBankInputController: TextEditingController(),
        correctOrderInputController: TextEditingController(),
      );

  // Populate controllers from an existing CardQuestion (edit mode).
  factory _QuestionState.fromQuestion(CardQuestion q) {
    switch (q) {
      case TextInputQuestion q:
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.fieldTypeTextInput,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController:
              TextEditingController(text: (q.correctAnswers ?? []).join(', ')),
          hintController: TextEditingController(text: q.hint ?? ''),
          exactMatch: q.exactMatch,
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
      case MultipleChoiceQuestion q:
        final opts = q.options ?? [];
        final optCtls = opts.isEmpty
            ? [TextEditingController(), TextEditingController()]
            : opts.map((o) => TextEditingController(text: o)).toList();
        while (optCtls.length < 2) {
          optCtls.add(TextEditingController());
        }
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.fieldTypeMultipleChoice,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: optCtls,
          correctIndex: q.correctIndex,
          displayMode: q.displayMode,
          explanationController:
              TextEditingController(text: q.explanation ?? ''),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
      case WordOrderQuestion q:
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.questionTypeWordOrder,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: List.from(q.wordBank ?? []),
          correctOrder: List.from(q.correctOrder ?? []),
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
      case FillInTheBlanksQuestion q:
        final state = _QuestionState(
          questionId: q.questionId,
          type: AppConstants.questionTypeFillInBlanks,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
        // Prefill the fill-in-blanks editor state (field-initialised members).
        state.fibSentenceController.text = q.sentence ?? '';
        state.fibTokens = List.from(q.tokens ?? const []);
        state.fibBlankCount = q.blankCount;
        state.fibExtraWords.addAll(q.extraWords);
        state.completionMode = q.completionMode;
        return state;
      case GridQuestion q:
        final state = _QuestionState(
          questionId: q.questionId,
          type: AppConstants.questionTypeGrid,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
        // Prefill the grid editor state from the stored cells/headers.
        for (final row in q.cells ?? const <List<String>>[]) {
          state.gridCells.add(
              row.map((v) => TextEditingController(text: v)).toList());
        }
        state.gridHasRowHeaders = q.rowHeaders.isNotEmpty;
        state.gridHasColHeaders = q.columnHeaders.isNotEmpty;
        state.gridRowHeaderCtls.addAll(
            q.rowHeaders.map((h) => TextEditingController(text: h)));
        state.gridColHeaderCtls.addAll(
            q.columnHeaders.map((h) => TextEditingController(text: h)));
        state.gridCornerCtl.text = q.cornerLabel;
        state.gridEmptyCount = q.emptyCount;
        state.gridExtraWords.addAll(q.extraWords);
        state.completionMode = q.completionMode;
        return state;
    }
  }

  // Build a CardQuestion from the current state of all controllers.
  CardQuestion toQuestion() {
    final promptText = promptController.text.trim();
    final prompt = promptText.isEmpty ? null : promptText;

    if (type == AppConstants.fieldTypeTextInput) {
      return TextInputQuestion(
        questionId: questionId,
        prompt: prompt,
        correctAnswers: answersController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        hint: hintController.text.trim().isEmpty
            ? null
            : hintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else if (type == AppConstants.fieldTypeMultipleChoice) {
      return MultipleChoiceQuestion(
        questionId: questionId,
        prompt: prompt,
        options: optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: correctIndex ?? 0,
        displayMode: displayMode,
        explanation: explanationController.text.trim().isEmpty
            ? null
            : explanationController.text.trim(),
      );
    } else if (type == AppConstants.questionTypeWordOrder) {
      return WordOrderQuestion(
        questionId: questionId,
        prompt: prompt,
        wordBank: List.from(wordBank),
        correctOrder: List.from(correctOrder),
      );
    } else if (type == AppConstants.questionTypeFillInBlanks) {
      final sentence = fibSentenceController.text.trim();
      return FillInTheBlanksQuestion(
        questionId: questionId,
        prompt: prompt,
        sentence: sentence.isEmpty ? null : sentence,
        tokens: fibTokens.isEmpty ? null : List.from(fibTokens),
        blankCount: fibBlankCount,
        extraWords: List.from(fibExtraWords),
        completionMode: completionMode,
      );
    } else {
      final cells = gridCells
          .map((row) => row.map((c) => c.text.trim()).toList())
          .toList();
      return GridQuestion(
        questionId: questionId,
        prompt: prompt,
        rowHeaders: gridHasRowHeaders
            ? gridRowHeaderCtls.map((c) => c.text.trim()).toList()
            : const [],
        columnHeaders: gridHasColHeaders
            ? gridColHeaderCtls.map((c) => c.text.trim()).toList()
            : const [],
        // Corner label only applies when both header axes are present.
        cornerLabel: (gridHasRowHeaders && gridHasColHeaders)
            ? gridCornerCtl.text.trim()
            : '',
        cells: cells.isEmpty ? null : cells,
        emptyCount: gridEmptyCount,
        extraWords: List.from(gridExtraWords),
        completionMode: completionMode,
      );
    }
  }

  void dispose() {
    promptController.dispose();
    answersController.dispose();
    hintController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    explanationController.dispose();
    wordBankInputController.dispose();
    correctOrderInputController.dispose();
    wordBankFocus.dispose();
    fibSentenceController.dispose();
    fibExtraWordInputController.dispose();
    fibExtraWordFocus.dispose();
    for (final row in gridCells) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final c in gridRowHeaderCtls) {
      c.dispose();
    }
    for (final c in gridColHeaderCtls) {
      c.dispose();
    }
    gridCornerCtl.dispose();
    gridExtraWordInputController.dispose();
    gridExtraWordFocus.dispose();
  }
}

// ---------------------------------------------------------------------------
// WorkbookCardFormScreen — create or edit a WorkbookCard.
// Pass [card] to pre-populate in edit mode; omit for create mode.
// Pass [parentSet] when creating from inside a set — its language pair is
// used as the default.
// ---------------------------------------------------------------------------
class WorkbookCardFormScreen extends ConsumerStatefulWidget {
  final WorkbookCard? card;
  final CardSet? parentSet;
  const WorkbookCardFormScreen({super.key, this.card, this.parentSet});

  @override
  ConsumerState<WorkbookCardFormScreen> createState() =>
      _WorkbookCardFormScreenState();
}

class _WorkbookCardFormScreenState
    extends ConsumerState<WorkbookCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _promptController;

  List<String> _tags = [];
  final List<_QuestionState> _questions = [];
  String? _nativeLanguage;
  String? _targetLanguage;
  bool _isSaving = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _promptController = TextEditingController(text: card?.prompt ?? '');
    _tags = List.from(card?.tags ?? []);
    if (card != null) {
      _questions.addAll(card.questions.map(_QuestionState.fromQuestion));
      _nativeLanguage = card.nativeLanguage;
      _targetLanguage = card.targetLanguage;
    } else if (widget.parentSet != null) {
      _nativeLanguage = widget.parentSet!.nativeLanguage;
      _targetLanguage = widget.parentSet!.targetLanguage;
    } else {
      final last = ref.read(lastUsedLanguagesProvider);
      _nativeLanguage = last?.native;
      _targetLanguage = last?.target;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_QuestionState.empty()));

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  // Swap the question at [from] with the adjacent one at [to].
  void _moveQuestion(int from, int to) {
    if (to < 0 || to >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(from);
      _questions.insert(to, q);
    });
  }

  // --- Multiple choice option management ------------------------------------

  void _addOption(int qIdx) => setState(
      () => _questions[qIdx].optionControllers.add(TextEditingController()));

  void _removeOption(int qIdx, int optIdx) {
    final q = _questions[qIdx];
    if (q.optionControllers.length <= 2) return;
    setState(() {
      q.optionControllers[optIdx].dispose();
      q.optionControllers.removeAt(optIdx);
      if (q.correctIndex == optIdx) {
        q.correctIndex = null;
      } else if (q.correctIndex != null && q.correctIndex! > optIdx) {
        q.correctIndex = q.correctIndex! - 1;
      }
    });
  }

  // --- Word order management ------------------------------------------------

  void _addWordBankTile(int qIdx, String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() => _questions[qIdx].wordBank.add(w));
    _questions[qIdx].wordBankInputController.clear();
    // Return focus so the next tile can be typed immediately.
    _questions[qIdx].wordBankFocus.requestFocus();
  }

  void _removeWordBankTile(int qIdx, int tileIdx) {
    setState(() {
      final q = _questions[qIdx];
      final removed = q.wordBank[tileIdx];
      q.wordBank.removeAt(tileIdx);
      q.correctOrder.remove(removed);
    });
  }

  void _removeCorrectOrderWord(int qIdx, int idx) =>
      setState(() => _questions[qIdx].correctOrder.removeAt(idx));

  // Returns word bank tiles not yet consumed by the current correct order,
  // preserving multiplicity so the same word can appear multiple times.
  List<String> _availableForCorrectOrder(int qIdx) {
    final q = _questions[qIdx];
    final remaining = List<String>.from(q.wordBank);
    for (final word in q.correctOrder) {
      remaining.remove(word); // removes first occurrence — multiset semantics
    }
    return remaining;
  }

  void _placeCorrectOrderWord(int qIdx, String word) =>
      setState(() => _questions[qIdx].correctOrder.add(word));

  // --- fill_in_blanks (#170) helpers ----------------------------------------

  int _fibEligibleCount(_QuestionState q) =>
      q.fibTokens.where((t) => t.eligible).length;

  // Split the sentence into word tokens (whitespace-separated), all initially
  // not-eligible. Replaces any existing tokens and resets blank count.
  void _tokenizeFib(int qIdx) {
    final q = _questions[qIdx];
    // Strips edge punctuation into leading/trailing; keeps contractions and
    // hyphenated words intact (see FillBlankToken.tokenize).
    final tokens = FillBlankToken.tokenize(q.fibSentenceController.text);
    setState(() {
      q.fibTokens = tokens;
      q.fibBlankCount = 1;
    });
  }

  // Toggle whether a token may be blanked; clamp blank count to eligible count.
  void _toggleFibEligible(int qIdx, int tokenIdx) {
    final q = _questions[qIdx];
    final t = q.fibTokens[tokenIdx];
    setState(() {
      // copyWith preserves leading/trailing punctuation affixes.
      q.fibTokens[tokenIdx] = t.copyWith(eligible: !t.eligible);
      final eligible = _fibEligibleCount(q);
      // Clamp blank count to [1, eligible]; when eligible hits 0 keep count
      // at 1 so the field stays valid and validation surfaces the real error.
      q.fibBlankCount = q.fibBlankCount.clamp(1, eligible < 1 ? 1 : eligible);
    });
  }

  void _setFibBlankCount(int qIdx, int count) {
    final q = _questions[qIdx];
    final eligible = _fibEligibleCount(q);
    setState(() => q.fibBlankCount = count.clamp(1, eligible < 1 ? 1 : eligible));
  }

  void _addFibExtraWord(int qIdx, String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() => _questions[qIdx].fibExtraWords.add(w));
    _questions[qIdx].fibExtraWordInputController.clear();
    // Return focus to the field so the next word can be typed immediately.
    _questions[qIdx].fibExtraWordFocus.requestFocus();
  }

  void _removeFibExtraWord(int qIdx, int idx) =>
      setState(() => _questions[qIdx].fibExtraWords.removeAt(idx));

  void _addGridExtraWord(int qIdx, String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() => _questions[qIdx].gridExtraWords.add(w));
    _questions[qIdx].gridExtraWordInputController.clear();
    _questions[qIdx].gridExtraWordFocus.requestFocus();
  }

  void _removeGridExtraWord(int qIdx, int idx) =>
      setState(() => _questions[qIdx].gridExtraWords.removeAt(idx));

  // --- grid (#167) helpers --------------------------------------------------

  int _gridRowCount(_QuestionState q) => q.gridCells.length;
  int _gridColCount(_QuestionState q) =>
      q.gridCells.isEmpty ? 0 : q.gridCells.first.length;
  int _gridTotalCells(_QuestionState q) =>
      _gridRowCount(q) * _gridColCount(q);

  // Create a default 2×2 grid the first time the grid type is selected.
  void _gridEnsureInit(_QuestionState q) {
    if (q.gridCells.isNotEmpty) return;
    for (var r = 0; r < 2; r++) {
      q.gridCells.add([TextEditingController(), TextEditingController()]);
    }
  }

  // Grow/shrink the number of rows, preserving existing cell content.
  void _gridSetRows(int qIdx, int rows) {
    final q = _questions[qIdx];
    final cols = _gridColCount(q).clamp(1, 99);
    setState(() {
      while (q.gridCells.length < rows) {
        q.gridCells
            .add(List.generate(cols, (_) => TextEditingController()));
        if (q.gridHasRowHeaders) q.gridRowHeaderCtls.add(TextEditingController());
      }
      while (q.gridCells.length > rows && q.gridCells.length > 1) {
        for (final c in q.gridCells.removeLast()) {
          c.dispose();
        }
        if (q.gridHasRowHeaders && q.gridRowHeaderCtls.isNotEmpty) {
          q.gridRowHeaderCtls.removeLast().dispose();
        }
      }
      _gridClampEmptyCount(q);
    });
  }

  // Grow/shrink the number of columns, preserving existing cell content.
  void _gridSetCols(int qIdx, int cols) {
    final q = _questions[qIdx];
    setState(() {
      for (final row in q.gridCells) {
        while (row.length < cols) {
          row.add(TextEditingController());
        }
        while (row.length > cols && row.length > 1) {
          row.removeLast().dispose();
        }
      }
      if (q.gridHasColHeaders) {
        while (q.gridColHeaderCtls.length < cols) {
          q.gridColHeaderCtls.add(TextEditingController());
        }
        while (q.gridColHeaderCtls.length > cols &&
            q.gridColHeaderCtls.isNotEmpty) {
          q.gridColHeaderCtls.removeLast().dispose();
        }
      }
      _gridClampEmptyCount(q);
    });
  }

  void _gridToggleRowHeaders(int qIdx, bool on) {
    final q = _questions[qIdx];
    setState(() {
      q.gridHasRowHeaders = on;
      if (on) {
        while (q.gridRowHeaderCtls.length < _gridRowCount(q)) {
          q.gridRowHeaderCtls.add(TextEditingController());
        }
      }
    });
  }

  void _gridToggleColHeaders(int qIdx, bool on) {
    final q = _questions[qIdx];
    setState(() {
      q.gridHasColHeaders = on;
      if (on) {
        while (q.gridColHeaderCtls.length < _gridColCount(q)) {
          q.gridColHeaderCtls.add(TextEditingController());
        }
      }
    });
  }

  void _gridSetEmptyCount(int qIdx, int count) {
    final q = _questions[qIdx];
    final total = _gridTotalCells(q);
    setState(() =>
        q.gridEmptyCount = count.clamp(1, total < 1 ? 1 : total));
  }

  void _gridClampEmptyCount(_QuestionState q) {
    final total = _gridTotalCells(q);
    if (q.gridEmptyCount > total) q.gridEmptyCount = total < 1 ? 1 : total;
    if (q.gridEmptyCount < 1) q.gridEmptyCount = 1;
  }

  // --- Save / Delete --------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = context.l10n;

    // Check that every MC question has a correct option selected.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.fieldTypeMultipleChoice &&
          q.correctIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.messageSelectCorrectOptionNumber(i + 1)),
        ));
        return;
      }
    }

    // Validate word order questions.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.questionTypeWordOrder) {
        if (q.wordBank.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageWordOrderNeedWordBank(i + 1)),
          ));
          return;
        }
        if (q.correctOrder.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageWordOrderNeedCorrectOrder(i + 1)),
          ));
          return;
        }
        for (final word in q.correctOrder) {
          if (!q.wordBank.contains(word)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.messageWordOrderWordNotInBank(i + 1, word)),
            ));
            return;
          }
        }
      }
    }

    // Validate fill-in-the-blanks questions.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.questionTypeFillInBlanks) {
        if (q.fibSentenceController.text.trim().isEmpty || q.fibTokens.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageFibNeedSentence(i + 1)),
          ));
          return;
        }
        if (_fibEligibleCount(q) == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageFibNeedEligible(i + 1)),
          ));
          return;
        }
      }
    }

    // Validate grid questions — every cell must be filled (a blank cell has no
    // valid answer when hidden).
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.questionTypeGrid) {
        final anyEmpty =
            q.gridCells.any((row) => row.any((c) => c.text.trim().isEmpty));
        if (q.gridCells.isEmpty || anyEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageGridFillAllCells(i + 1)),
          ));
          return;
        }
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final tagRepo = ref.read(tagRepositoryProvider);
      final questions = _questions.map((q) => q.toQuestion()).toList();

      // Normalise tags so stored values match tags/{normalizedName} doc IDs.
      final normalizedTags = _tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();

      if (!_isEditing) {
        final now = DateTime.now();
        await ref.read(workbookCardRepositoryProvider).createCard(
              WorkbookCard(
                id: '',
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: normalizedTags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
                createdAt: now,
                updatedAt: now,
                createdBy: uid,
              ),
            );
        ref.read(lastUsedLanguagesProvider.notifier).set(
              (native: _nativeLanguage, target: _targetLanguage),
            );
        // Fire-and-forget tag upserts so a count failure never blocks save.
        for (final tag in normalizedTags) { tagRepo.upsertTag(tag, uid); }
      } else {
        final (toUpsert, toDecrement) =
            AppHelpers.diffTags(widget.card!.tags, normalizedTags);
        await ref.read(workbookCardRepositoryProvider).updateCard(
              widget.card!.copyWith(
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: normalizedTags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
              ),
            );
        for (final tag in toUpsert) { tagRepo.upsertTag(tag, uid); }
        for (final norm in toDecrement) { tagRepo.decrementTag(norm); }
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedSaveCard)),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleDeleteWorkbookCard),
        content: Text(l10n.messageDeleteWorkbookCardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.labelDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final tagsToDecrement = widget.card!.tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();
      final tagRepo = ref.read(tagRepositoryProvider);
      await ref
          .read(workbookCardRepositoryProvider)
          .deleteCard(widget.card!.id);
      for (final norm in tagsToDecrement) { tagRepo.decrementTag(norm); }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedDeleteCard)),
        );
      }
    }
  }

  // --- Question content builders --------------------------------------------

  Widget _buildTextInputContent(_QuestionState q) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: q.answersController,
          decoration: InputDecoration(
            labelText: l10n.labelCorrectAnswersRequired,
            hintText: l10n.hintCorrectAnswersExample,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            final answers = (v ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            return answers.isEmpty ? l10n.validatorAtLeastOneAnswer : null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.hintController,
          decoration: InputDecoration(
            labelText: l10n.labelHintOptional,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: Text(l10n.labelExactMatch),
          subtitle: Text(l10n.messageExactMatchSubtitle),
          value: q.exactMatch,
          onChanged: (v) => setState(() => q.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display mode chip selector.
        Row(
          children: [
            Text(l10n.labelDisplay,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(l10n.labelDisplayList),
              selected: q.displayMode == MultipleChoiceDisplayMode.list,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.list),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: Text(l10n.labelDisplayChips),
              selected: q.displayMode == MultipleChoiceDisplayMode.chips,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.chips),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.labelOptionsRequired,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // RadioGroup groups all Radio children around a shared value.
        RadioGroup<int>(
          groupValue: q.correctIndex,
          onChanged: (v) => setState(() => q.correctIndex = v),
          child: Column(
            children: List.generate(q.optionControllers.length, (optIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(value: optIdx),
                    Expanded(
                      child: TextFormField(
                        controller: q.optionControllers[optIdx],
                        decoration: InputDecoration(
                          labelText: l10n.labelOptionNumber(optIdx + 1),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty ?? true
                            ? l10n.validatorOptionTextRequired
                            : null,
                      ),
                    ),
                    if (q.optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _removeOption(qIdx, optIdx),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        TextButton.icon(
          onPressed: () => _addOption(qIdx),
          icon: const Icon(Icons.add),
          label: Text(l10n.actionAddOption),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.explanationController,
          decoration: InputDecoration(
            labelText: l10n.labelExplanationOptional,
            hintText: l10n.hintExplanationShownAfterAnswer,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOrderContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final available = _availableForCorrectOrder(qIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Word Bank -------------------------------------------------
        Text(l10n.labelWordBankRequired,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(l10n.messageWordBankHelp, style: muted),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: q.wordBankInputController,
                focusNode: q.wordBankFocus,
                decoration: InputDecoration(
                  hintText: l10n.hintAddWordTile,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => _addWordBankTile(qIdx, v),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  _addWordBankTile(qIdx, q.wordBankInputController.text),
              child: Text(l10n.actionAdd),
            ),
          ],
        ),
        if (q.wordBank.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: q.wordBank
                .asMap()
                .entries
                .map((e) => Chip(
                      label: Text(e.value),
                      onDeleted: () => _removeWordBankTile(qIdx, e.key),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),

        // -- Correct Order (tap tiles to build sequence) ---------------
        Row(
          children: [
            Text(l10n.labelCorrectOrderRequired,
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (q.correctOrder.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => q.correctOrder.clear()),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: Text(l10n.actionClear),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(l10n.messageCorrectOrderHelp, style: muted),
        const SizedBox(height: 8),

        // Answer sequence — placed tiles with sequence numbers.
        // Tap the × to return a tile to the available pool.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: q.correctOrder.isEmpty
              ? Text(
                  q.wordBank.isEmpty
                      ? l10n.messageAddTilesToWordBankFirst
                      : l10n.messageTapTilesBelow,
                  style: muted,
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: q.correctOrder.asMap().entries.map((e) {
                    return Chip(
                      label: Text('${e.key + 1}. ${e.value}'),
                      onDeleted: () => _removeCorrectOrderWord(qIdx, e.key),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 8),

        // Available tiles — derived from word bank minus already placed.
        if (available.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: available
                .map((word) => ActionChip(
                      label: Text(word),
                      onPressed: () => _placeCorrectOrderWord(qIdx, word),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.add, size: 16),
                    ))
                .toList(),
          )
        else if (q.wordBank.isNotEmpty)
          Text(l10n.labelAllTilesPlaced, style: muted),
      ],
    );
  }

  // Fill-in-the-blanks editor (#170): sentence → Tokenize → tap words to mark
  // eligible → set blank count → optional distractor words.
  Widget _buildFillInBlanksContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final eligibleCount = _fibEligibleCount(q);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Completion mode selector ---------------------------------------
        _buildCompletionModeSelector(q, qIdx),
        const SizedBox(height: 12),

        // -- Sentence + Tokenize --------------------------------------------
        Text(l10n.labelFibSentenceRequired,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(l10n.messageFibSentenceHelp, style: muted),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: q.fibSentenceController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.hintFibSentenceExample,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _tokenizeFib(qIdx),
              child: Text(l10n.actionTokenize),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // -- Tokens: tap to mark eligible -----------------------------------
        if (q.fibTokens.isEmpty)
          Text(l10n.messageFibTokenizeFirst, style: muted)
        else ...[
          Text(l10n.messageFibMarkEligible, style: muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: q.fibTokens.asMap().entries.map((e) {
              return FilterChip(
                label: Text(e.value.word),
                selected: e.value.eligible,
                onSelected: (_) => _toggleFibEligible(qIdx, e.key),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // -- Number of blanks ---------------------------------------------
          Row(
            children: [
              Text(l10n.labelFibBlankCount,
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 22,
                tooltip: l10n.tooltipDecrease,
                onPressed: q.fibBlankCount > 1
                    ? () => _setFibBlankCount(qIdx, q.fibBlankCount - 1)
                    : null,
              ),
              Text('${q.fibBlankCount}',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 22,
                tooltip: l10n.tooltipIncrease,
                onPressed: q.fibBlankCount < eligibleCount
                    ? () => _setFibBlankCount(qIdx, q.fibBlankCount + 1)
                    : null,
              ),
            ],
          ),
          Text(l10n.messageFibBlankCountHelp(eligibleCount), style: muted),
          const SizedBox(height: 16),

          // -- Distractor words (optional, pill mode only) ------------------
          if (q.completionMode == CompletionMode.pill) ...[
            Text(l10n.labelFibDistractorsOptional,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(l10n.messageFibDistractorsHelp, style: muted),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: q.fibExtraWordInputController,
                    focusNode: q.fibExtraWordFocus,
                    decoration: InputDecoration(
                      hintText: l10n.hintFibDistractorWord,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => _addFibExtraWord(qIdx, v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _addFibExtraWord(
                      qIdx, q.fibExtraWordInputController.text),
                  child: Text(l10n.actionAdd),
                ),
              ],
            ),
            if (q.fibExtraWords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: q.fibExtraWords
                    .asMap()
                    .entries
                    .map((e) => Chip(
                          label: Text(e.value),
                          onDeleted: () => _removeFibExtraWord(qIdx, e.key),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ],
      ],
    );
  }

  // Complete-the-grid editor (#167): row/column steppers (resize in place,
  // preserving content), optional header toggles, an editable cell grid, and
  // an empty-count stepper. Pill mode only for now (text-input mode with #168).
  Widget _buildGridContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final rows = _gridRowCount(q);
    final cols = _gridColCount(q);
    final total = _gridTotalCells(q);
    const maxDim = 8; // keep grids manageable on phone screens

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Completion mode selector ---------------------------------------
        _buildCompletionModeSelector(q, qIdx),
        const SizedBox(height: 12),

        Text(l10n.messageGridHelp, style: muted),
        const SizedBox(height: 12),

        // -- Dimension steppers ---------------------------------------------
        Row(
          children: [
            Expanded(
              child: _gridStepper(
                label: l10n.labelGridRows,
                value: rows,
                onDecrease:
                    rows > 1 ? () => _gridSetRows(qIdx, rows - 1) : null,
                onIncrease:
                    rows < maxDim ? () => _gridSetRows(qIdx, rows + 1) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _gridStepper(
                label: l10n.labelGridColumns,
                value: cols,
                onDecrease:
                    cols > 1 ? () => _gridSetCols(qIdx, cols - 1) : null,
                onIncrease:
                    cols < maxDim ? () => _gridSetCols(qIdx, cols + 1) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // -- Header toggles -------------------------------------------------
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.labelGridColumnHeaders,
                    style: Theme.of(context).textTheme.bodySmall),
                value: q.gridHasColHeaders,
                onChanged: (v) => _gridToggleColHeaders(qIdx, v ?? false),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.labelGridRowHeaders,
                    style: Theme.of(context).textTheme.bodySmall),
                value: q.gridHasRowHeaders,
                onChanged: (v) => _gridToggleRowHeaders(qIdx, v ?? false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // -- Editable cell grid (horizontally scrollable) -------------------
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column-header row.
              if (q.gridHasColHeaders)
                Row(
                  children: [
                    // Top-left corner: an optional title for the row-label
                    // column (e.g. "Pronoun"), editable when both headers are on.
                    if (q.gridHasRowHeaders)
                      _gridFieldBox(
                        controller: q.gridCornerCtl,
                        hint: l10n.hintGridCornerLabel,
                        header: true,
                      ),
                    for (var c = 0; c < cols; c++)
                      _gridFieldBox(
                        controller: c < q.gridColHeaderCtls.length
                            ? q.gridColHeaderCtls[c]
                            : TextEditingController(),
                        hint: l10n.hintGridHeader,
                        header: true,
                      ),
                  ],
                ),
              // Data rows.
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    if (q.gridHasRowHeaders)
                      _gridFieldBox(
                        controller: r < q.gridRowHeaderCtls.length
                            ? q.gridRowHeaderCtls[r]
                            : TextEditingController(),
                        hint: l10n.hintGridHeader,
                        header: true,
                      ),
                    for (var c = 0; c < cols; c++)
                      _gridFieldBox(
                        controller: q.gridCells[r][c],
                        hint: l10n.hintGridCell,
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // -- Empty-cell count -----------------------------------------------
        Row(
          children: [
            Text(l10n.labelGridEmptyCells,
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 22,
              tooltip: l10n.tooltipDecrease,
              onPressed: q.gridEmptyCount > 1
                  ? () => _gridSetEmptyCount(qIdx, q.gridEmptyCount - 1)
                  : null,
            ),
            Text('${q.gridEmptyCount}',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 22,
              tooltip: l10n.tooltipIncrease,
              onPressed: q.gridEmptyCount < total
                  ? () => _gridSetEmptyCount(qIdx, q.gridEmptyCount + 1)
                  : null,
            ),
          ],
        ),
        Text(l10n.messageGridEmptyCountHelp(total), style: muted),
        const SizedBox(height: 16),

        // -- Distractor words (optional, pill mode only) --------------------
        if (q.completionMode == CompletionMode.pill) ...[
          Text(l10n.labelFibDistractorsOptional,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(l10n.messageFibDistractorsHelp, style: muted),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: q.gridExtraWordInputController,
                  focusNode: q.gridExtraWordFocus,
                  decoration: InputDecoration(
                    hintText: l10n.hintFibDistractorWord,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => _addGridExtraWord(qIdx, v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    _addGridExtraWord(qIdx, q.gridExtraWordInputController.text),
                child: Text(l10n.actionAdd),
              ),
            ],
          ),
          if (q.gridExtraWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: q.gridExtraWords
                  .asMap()
                  .entries
                  .map((e) => Chip(
                        label: Text(e.value),
                        onDeleted: () => _removeGridExtraWord(qIdx, e.key),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ],
    );
  }

  // SegmentedButton that toggles between pill and text-input completion modes.
  // Shared by FIB and Grid question editors.
  Widget _buildCompletionModeSelector(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.labelCompletionMode,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 12),
        SegmentedButton<CompletionMode>(
          segments: [
            ButtonSegment(
              value: CompletionMode.pill,
              label: Text(l10n.labelCompletionModePill),
              icon: const Icon(Icons.view_module_outlined),
            ),
            ButtonSegment(
              value: CompletionMode.textInput,
              label: Text(l10n.labelCompletionModeText),
              icon: const Icon(Icons.keyboard_outlined),
            ),
          ],
          selected: {q.completionMode},
          onSelectionChanged: (s) =>
              setState(() => _questions[qIdx].completionMode = s.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  // A compact +/- stepper with a centred value, used for grid dimensions.
  Widget _gridStepper({
    required String label,
    required int value,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 22,
              tooltip: context.l10n.tooltipDecrease,
              onPressed: onDecrease,
            ),
            Text('$value', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 22,
              tooltip: context.l10n.tooltipIncrease,
              onPressed: onIncrease,
            ),
          ],
        ),
      ],
    );
  }

  // One fixed-width cell/header text field in the grid editor.
  Widget _gridFieldBox(
      {required TextEditingController controller,
      required String hint,
      bool header = false}) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 92,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: header
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: header,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final l10n = context.l10n;
    final q = _questions[index];
    return Card(
      key: ValueKey(q.questionId),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: label + reorder + delete.
            Row(
              children: [
                Text(l10n.labelQuestionNumber(index + 1),
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: 20,
                  tooltip: l10n.tooltipMoveUp,
                  onPressed:
                      index > 0 ? () => _moveQuestion(index, index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 20,
                  tooltip: l10n.tooltipMoveDown,
                  onPressed: index < _questions.length - 1
                      ? () => _moveQuestion(index, index + 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.error,
                  tooltip: l10n.tooltipRemoveQuestion,
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Optional per-question label.
            TextFormField(
              controller: q.promptController,
              decoration: InputDecoration(
                labelText: l10n.labelQuestionLabelFullOptional,
                hintText: l10n.hintQuestionLabelWorkbookExample,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Type selector.
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: InputDecoration(
                labelText: l10n.labelQuestionType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: AppConstants.fieldTypeTextInput,
                  child: Text(l10n.labelQuestionTypeTextInput),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeMultipleChoice,
                  child: Text(l10n.labelQuestionTypeMultipleChoice),
                ),
                DropdownMenuItem(
                  value: AppConstants.questionTypeWordOrder,
                  child: Text(l10n.labelQuestionTypeWordOrder),
                ),
                DropdownMenuItem(
                  value: AppConstants.questionTypeFillInBlanks,
                  child: Text(l10n.labelQuestionTypeFillInBlanks),
                ),
                DropdownMenuItem(
                  value: AppConstants.questionTypeGrid,
                  child: Text(l10n.labelQuestionTypeGrid),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    q.type = v;
                    // Lazily seed a default grid the first time it's chosen.
                    if (v == AppConstants.questionTypeGrid) _gridEnsureInit(q);
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Type-specific content.
            if (q.type == AppConstants.fieldTypeTextInput)
              _buildTextInputContent(q),
            if (q.type == AppConstants.fieldTypeMultipleChoice)
              _buildMultipleChoiceContent(q, index),
            if (q.type == AppConstants.questionTypeWordOrder)
              _buildWordOrderContent(q, index),
            if (q.type == AppConstants.questionTypeFillInBlanks)
              _buildFillInBlanksContent(q, index),
            if (q.type == AppConstants.questionTypeGrid)
              _buildGridContent(q, index),
          ],
        ),
      ),
    );
  }

  // --- Main build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.titleEditWorkbookCard : l10n.titleNewWorkbookCard),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.tooltipDeleteCard,
              onPressed: _isSaving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: IgnorePointer(
          ignoring: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Prompt -----------------------------------------------
                Text(l10n.titlePromptSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  l10n.messagePromptSectionHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: l10n.labelPromptRequired,
                    hintText: l10n.hintPromptExample,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? l10n.validatorPromptRequired : null,
                ),

                // --- Languages --------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleLanguagesSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: l10n.labelTargetLanguage,
                  value: _targetLanguage,
                  onChanged: (v) => setState(() => _targetLanguage = v),
                ),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: l10n.labelNativeLanguage,
                  value: _nativeLanguage,
                  onChanged: (v) => setState(() => _nativeLanguage = v),
                ),

                // --- Tags -------------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleTagsSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TagInputField(
                  tags: _tags,
                  enabled: !_isSaving,
                  onChanged: (updated) => setState(() => _tags = updated),
                ),

                // --- Questions --------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleQuestionsSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key)),
                OutlinedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.actionAddQuestion),
                ),

                // --- Save / Cancel ----------------------------------------
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.labelCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEditing
                                ? l10n.actionSaveChanges
                                : l10n.actionCreateCard),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
