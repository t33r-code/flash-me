import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_mark_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/question_result_provider.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/theme/app_colors.dart';
import 'package:flash_me/screens/study/study_session_summary_screen.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/utils/question_reveal.dart';
import 'package:flash_me/utils/study_filters.dart';
import 'package:flash_me/utils/transitions.dart';

// Workbook question-card widgets and their shared helpers live in part files
// under question_cards/ — split out from this screen (#194). They share this
// library's imports and its underscore-private helpers (e.g. the haptic
// functions, now in question_card_shared.dart).
part 'question_cards/question_card_shared.dart';
part 'question_cards/workbook_text_input_card.dart';
part 'question_cards/workbook_multiple_choice_card.dart';
part 'question_cards/word_order_card.dart';
part 'question_cards/fill_in_the_blanks_card.dart';
part 'question_cards/grid_card.dart';

// ---------------------------------------------------------------------------
// StudySessionScreen — displays one card at a time from a StudySession.
//
// Card data is loaded via cardsInSetProvider (already streamed by the set
// detail screen, so no extra Firestore reads on first open).
//
// Phase 5c: Know/Don't Know marking, per-card state tracking, debounced
// auto-save (~1 s after each action), End (pause), and session completion.
// Phase 7:  The translation-reveal intermediate state lives inside _WordCard
// (AnimatedCrossFade) so the word stays put. The parent only tracks whether
// the card has been fully revealed (slide + fields + Know/Don't Know).
// ---------------------------------------------------------------------------
class StudySessionScreen extends ConsumerStatefulWidget {
  final StudySession session;
  final CardSet cardSet;
  const StudySessionScreen({
    super.key,
    required this.session,
    required this.cardSet,
  });

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  late int _currentIndex;
  // false = _WordCard handles word + translation-reveal internally (no slide).
  // true  = card slides to top and additional fields appear.
  bool _fullyRevealed = false;
  // Mutable local copy; updated on every user action and persisted via auto-save.
  late StudySession _session;
  // Debounce timer — restarted on each action, fires after 1 s to write Firestore.
  Timer? _saveDebounce;
  // Prevents double-tapping End or Finish while a save is in flight.
  bool _saving = false;
  // True while a background auto-save has failed; drives the warning banner.
  bool _saveFailed = false;

  // Flash + workbook card content, fetched once on init by ID. The session owns
  // a fixed cardSequence + cardTypeMap, so it loads content by ID rather than
  // via live set membership. Each map is keyed by card ID.
  Map<String, FlashCard> _flashCardsMap = {};
  Map<String, WorkbookCard> _workbookCardsMap = {};
  // True once the initial card batch has loaded (or failed).
  bool _flashCardsLoaded = false;
  bool _workbookCardsLoaded = false;
  // True if the initial load threw — drives the error view.
  bool _cardLoadFailed = false;

  // Question keys ('{cardId}_{questionId}') already counted toward the session
  // score. Ensures first-attempt-only scoring — re-answers after back-navigation
  // don't re-count.
  final Set<String> _countedQuestions = {};

  // Re-queue missed cards (#214): true once any question on the CURRENT visit
  // was answered incorrectly; reset each time we move to a card. Combined with a
  // "Not yet" self-eval at advance time to decide whether to re-queue.
  bool _currentCardMissed = false;

  // Progressive reveal (#215): 0-based indices of questions on the CURRENT card
  // that have been answered this visit. Drives which later questions are still
  // collapsed to a label. Reset on every card change (fresh visit).
  final Set<int> _answeredQuestions = {};

  // Sequence positions whose recall contribution has already been counted, so
  // each visit is graded exactly once. Every visit (including a re-queued
  // repeat, which occupies a new position) is a separate graded experience;
  // back-navigating to an already-left position does not re-count.
  late final Set<int> _finalizedPositions;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.session.currentCardIndex;
    _session = widget.session;
    // Total experiences high-water: at least the card currently on screen.
    // Re-queued repeats each occupy a new position, so this counts every visit.
    final seen = _currentIndex + 1;
    if (seen > _session.totalCardsStudied) {
      _session = _session.copyWith(totalCardsStudied: seen);
    }
    // When resuming THIS same session, positions before the resume point were
    // already graded earlier in this run and are counted in this session's own
    // restored tallies. Seed them as finalized so navigating back then forward
    // doesn't double-count them. (A brand-new session — Start New / Study Again —
    // starts with empty tallies and an empty set; no cross-session carry-over.)
    _finalizedPositions = {for (var i = 0; i < _currentIndex; i++) i};
    _loadSessionCards();
  }

  // Fetches all card content for this session in one batch, by ID.
  //
  // Both card types load the same way: the session owns a fixed cardSequence +
  // cardTypeMap, so content is fetched by ID rather than via live set
  // membership. Workbook cards are explicitly typed; anything else is treated
  // as a flashcard (old sessions have an empty cardTypeMap and are all flash).
  Future<void> _loadSessionCards() async {
    final seq = _session.cardSequence;
    final types = _session.cardTypeMap;
    final workbookIds = seq
        .where((id) => types[id] == AppConstants.cardTypeWorkbook)
        .toList();
    final flashIds = seq
        .where((id) => types[id] != AppConstants.cardTypeWorkbook)
        .toList();

    final uid = _uid;
    List<FlashCard> flash = [];
    List<WorkbookCard> workbook = [];
    bool failed = false;

    // Fetch both types in parallel; a failure in one shouldn't blank the other.
    await Future.wait([
      () async {
        try {
          flash = await ref
              .read(cardRepositoryProvider)
              .getCardsByIds(flashIds, uid);
        } catch (_) {
          failed = true;
        }
      }(),
      () async {
        try {
          workbook = await ref
              .read(workbookCardRepositoryProvider)
              .getCardsByIds(workbookIds, uid);
        } catch (_) {
          failed = true;
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _flashCardsMap = {for (final c in flash) c.id: c};
      _workbookCardsMap = {for (final c in workbook) c.id: c};
      _flashCardsLoaded = true;
      _workbookCardsLoaded = true;
      // Only surfaces the error view when nothing loaded (see _buildCardArea);
      // a partial success still shows whatever cards did load.
      _cardLoadFailed = failed;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  String get _uid => ref.read(authStateProvider).asData?.value ?? '';
  String get _currentCardId => _session.cardSequence[_currentIndex];
  int get _total => _session.cardSequence.length;

  // Per-card progress for whichever card is currently on screen.
  CardSessionData get _currentCardData =>
      _session.cardProgress[_currentCardId] ?? const CardSessionData();

  // Whether the current card is showing its full answer — accounts for
  // questionAsCard workbook cards, which start fully revealed without ever
  // flipping _fullyRevealed itself (see _buildWorkbookView's OR condition).
  bool get _isRevealed =>
      _fullyRevealed ||
      (_workbookCardsMap[_currentCardId]?.questionAsCard ?? false);

  // Desktop keyboard shortcuts (#87): ← → previous/next, Enter reveal/advance,
  // K/1 mark Skip, U/2 mark Review. Deliberately does nothing while a text
  // field has focus (in-progress questions) — see _isTextFieldFocused.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isTextFieldFocused()) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _previous();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _next();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // One press reveals everything (translation + any extra questions,
        // matching a tap + More together); a second press advances — fewer
        // keystrokes for a fast keyboard-driven review loop.
        if (!_isRevealed) {
          setState(() => _fullyRevealed = true);
        } else {
          _next();
        }
        return KeyEventResult.handled;
      // Digits follow the nav bar's left-to-right display order (Review,
      // then Skip) rather than pairing with their letter mnemonic — 1 is
      // Review, 2 is Skip, even though U/Review and K/Skip pair together.
      case LogicalKeyboardKey.keyK:
      case LogicalKeyboardKey.digit2:
        _updateCardMark(markSkip: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyU:
      case LogicalKeyboardKey.digit1:
        _updateCardMark(markSkip: false);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  // True while a text-editing field (a question's answer box) holds focus.
  // Guards every shortcut above — without this, typing a literal 'k'/'u' (or
  // even just using arrow keys to move the cursor) while answering a
  // text-input question would double as a study-navigation shortcut.
  //
  // The focused context's own widget is the `Focus` that EditableText wraps
  // itself in, never EditableText itself — verified in
  // test/screens/study/study_keyboard_shortcuts_test.dart, which caught this
  // exact mistake (a plain `is EditableText` check) failing to detect a
  // focused field at all. Hence the ancestor walk instead.
  bool _isTextFieldFocused() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _fullyRevealed = false;
        _currentCardMissed = false; // fresh visit — recompute miss state
        _answeredQuestions.clear(); // fresh visit — questions start collapsed
        _session = _session.copyWith(currentCardIndex: _currentIndex);
      });
      _scheduleAutoSave();
    }
  }

  // On last card, Next triggers session completion instead of advancing.
  void _next() {
    // Count this visit's recall result before leaving the card.
    _finalizeCurrentVisit();

    // The card is "missed" this visit if any question was answered wrong OR the
    // user self-evaluated the primary word as "Not yet" (#214).
    final missed =
        _currentCardMissed ||
        _currentCardData.primaryResult == AppConstants.primaryResultUnknown;

    // Re-queue the current card to the back if it was missed. This may grow the
    // sequence, so it happens before the last-card check below — a re-queued
    // last card advances into its new copy instead of completing.
    final newSeq = requeueMissedCard(
      _session.cardSequence,
      _currentIndex,
      enabled: _session.requeueMissed,
      missed: missed,
    );
    if (!identical(newSeq, _session.cardSequence)) {
      _session = _session.copyWith(cardSequence: newSeq);
    }

    if (_currentIndex < _total - 1) {
      final next = _currentIndex + 1;
      setState(() {
        _currentIndex = next;
        _fullyRevealed = false;
        _currentCardMissed = false;
        _answeredQuestions.clear(); // fresh visit — questions start collapsed
        _session = _session.copyWith(
          currentCardIndex: next,
          // Total experiences high-water: every visit counts, so a re-queued
          // repeat (a new position) increments this just like a fresh card.
          totalCardsStudied: next + 1 > _session.totalCardsStudied
              ? next + 1
              : _session.totalCardsStudied,
        );
      });
      _scheduleAutoSave();
    } else {
      _completeSession();
    }
  }

  // Toggle the Skip / Review mark for the current card.
  // Tapping the active button clears it; tapping the other switches to it.
  // The mark is also persisted to users/{uid}/cardMarks/{cardId} for use
  // by future filtered study modes.
  void _updateCardMark({required bool markSkip}) {
    HapticFeedback.selectionClick();
    final data = _currentCardData;
    final wasActive = markSkip ? data.markedKnown : data.markedUnknown;

    final newSkip = markSkip ? !wasActive : false;
    final newReview = !markSkip ? !wasActive : false;

    final updated = Map<String, CardSessionData>.from(_session.cardProgress);
    updated[_currentCardId] = data.copyWith(
      markedKnown: newSkip,
      markedUnknown: newReview,
    );

    // Skip/Review are persistent per-card marks only — they no longer drive the
    // session score. cardsKnown/cardsUnknown are set by _setPrimaryResult instead.
    setState(() {
      _session = _session.copyWith(cardProgress: updated);
    });

    // Persist the mark globally — fire-and-forget, errors don't interrupt study.
    final repo = ref.read(cardMarkRepositoryProvider);
    final cardId = _currentCardId;
    if (newSkip) {
      repo.setMark(_uid, cardId, AppConstants.markSkip).ignore();
    } else if (newReview) {
      repo.setMark(_uid, cardId, AppConstants.markReview).ignore();
    } else {
      repo.removeMark(_uid, cardId).ignore();
    }

    _scheduleAutoSave();
  }

  // Records the user's self-evaluation of the primary word recall for the
  // current card into the progress map (for UI highlight + resume). The recall
  // tallies are NOT recomputed here — each visit's contribution is counted once
  // when the user leaves the card (see _finalizeCurrentVisit), so re-queued
  // repeats each count as a separate experience (#214).
  void _setPrimaryResult(String result) {
    HapticFeedback.selectionClick();
    final updated = Map<String, CardSessionData>.from(_session.cardProgress);
    updated[_currentCardId] = _currentCardData.copyWith(
      primaryResult: result,
      status: AppConstants.cardStatusAnswered,
    );

    setState(() {
      _session = _session.copyWith(cardProgress: updated);
    });
    _scheduleAutoSave();
  }

  // Counts the current visit's recall result toward the session tallies, exactly
  // once per sequence position (#214). Every visit — including a re-queued
  // repeat, which occupies a new position — is a distinct graded experience;
  // back-navigating to an already-left position does not re-count. Workbook
  // cards never set primaryResult, so they contribute nothing here.
  void _finalizeCurrentVisit() {
    if (!_finalizedPositions.add(_currentIndex)) return; // already counted
    final result = _currentCardData.primaryResult;
    if (result == AppConstants.primaryResultKnown) {
      _session = _session.copyWith(cardsKnown: _session.cardsKnown + 1);
    } else if (result == AppConstants.primaryResultUnknown) {
      _session = _session.copyWith(cardsUnknown: _session.cardsUnknown + 1);
    }
  }

  // Cancel any pending save and restart the countdown.
  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveNow);
  }

  // Writes the current session to Firestore.
  // On failure: shows a persistent MaterialBanner so the user knows progress
  // may not be saving.  On recovery: banner is hidden automatically.
  Future<void> _saveNow() async {
    final l10n = context.l10n;
    try {
      await ref
          .read(studySessionRepositoryProvider)
          .saveSession(_session, _uid);
      if (_saveFailed && mounted) {
        setState(() => _saveFailed = false);
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    } catch (_) {
      if (!_saveFailed && mounted) {
        setState(() => _saveFailed = true);
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            content: Text(l10n.messageSaveProgressFailed),
            leading: const Icon(Icons.cloud_off_outlined),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _saveFailed = false);
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: Text(l10n.actionDismiss),
              ),
            ],
          ),
        );
      }
    }
  }

  // "End" button — fires the final save and pops immediately without awaiting.
  // The session is auto-saved every ~1 s, so at most one second of state is
  // deferred to the background write. On platforms with Firestore persistence
  // (mobile/web) the write queues locally and syncs when back online.
  void _endSession() {
    if (_saving) return;
    setState(() => _saving = true);
    _saveDebounce?.cancel();
    ref
        .read(studySessionRepositoryProvider)
        .saveSession(_session, _uid)
        .ignore();
    if (mounted) Navigator.of(context).pop();
  }

  // Triggered when the user taps Next on the last card.
  // Computes SessionStats, marks the session completed in Firestore, then
  // shows a summary dialog before popping back to the setup screen.
  Future<void> _completeSession() async {
    if (_saving) return;
    setState(() => _saving = true);
    _saveDebounce?.cancel();

    final now = DateTime.now();
    final totalMs = now.difference(_session.startTime).inMilliseconds;
    final studied = _session.totalCardsStudied > 0
        ? _session.totalCardsStudied
        : _total;
    final stats = SessionStats(
      totalTimeSpent: totalMs,
      avgTimePerCard: studied > 0 ? totalMs / studied : 0,
      correctAnswers: _session.cardsKnown,
      incorrectAnswers: _session.cardsUnknown,
      skipped: studied - _session.cardsKnown - _session.cardsUnknown,
    );

    final completed = _session.copyWith(
      totalCardsStudied: studied,
      sessionStats: stats,
    );

    // Fire-and-forget: the summary screen uses local data, so we don't need
    // to wait for Firestore before navigating.
    ref
        .read(studySessionRepositoryProvider)
        .completeSession(completed, _uid)
        .ignore();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        studySurfaceRoute(
          StudySessionSummaryScreen(
            session: completed,
            cardSet: widget.cardSet,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Desktop keyboard shortcuts (#87). autofocus only claims focus if
      // nothing else has (e.g. no answer field is focused yet) — it doesn't
      // steal focus away from a text field the user has since tapped into.
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.cardSet.name),
          actions: [
            TextButton(
              // Disable while a save is in flight to prevent double-tap.
              onPressed: _saving ? null : _endSession,
              child: Text(context.l10n.actionEnd),
            ),
          ],
        ),
        body: Column(
          children: [
            // Thin bar showing how far through the session the user is.
            LinearProgressIndicator(value: (_currentIndex + 1) / _total),

            // Card content — two-phase:
            //   • Before reveal: word card centred on screen (_WordCard)
            //   • After tap: card slides to top, fields appear below
            Expanded(child: _buildCardArea(context)),

            // Navigation bar — Previous/Next + Know/Don't Know marking.
            _NavigationBar(
              currentIndex: _currentIndex,
              total: _total,
              onPrevious: _previous,
              onNext: _next,
              onSkip: () => _updateCardMark(markSkip: true),
              onReview: () => _updateCardMark(markSkip: false),
              isMarkedSkip: _currentCardData.markedKnown,
              isMarkedReview: _currentCardData.markedUnknown,
            ),
          ],
        ),
      ),
    );
  }

  // Builds the central card area: a spinner until the initial card batch is
  // ready, an error message if the load failed, otherwise the current card
  // (workbook or flash) routed to its view.
  Widget _buildCardArea(BuildContext context) {
    if (!_flashCardsLoaded || !_workbookCardsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    // Nothing loaded and the fetch failed — show the error message.
    if (_cardLoadFailed &&
        _flashCardsMap.isEmpty &&
        _workbookCardsMap.isEmpty) {
      return Center(child: Text(context.l10n.errorFailedLoadCards));
    }

    final flashCard = _flashCardsMap[_currentCardId];
    final workbookCard = _workbookCardsMap[_currentCardId];

    // Route to the workbook view if this card is a workbook card.
    if (workbookCard != null) {
      return _buildWorkbookView(workbookCard);
    }
    if (flashCard == null) {
      return Center(child: Text(context.l10n.messageCardNotFound));
    }

    // Flash card view — two-phase reveal.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          // Incoming content rises in from slightly below.
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      // _WordCard keeps the same key whether or not translation is visible, so
      // AnimatedSwitcher only fires for the fully-revealed transition.
      child: _fullyRevealed
          ? SingleChildScrollView(
              key: ValueKey('$_currentIndex-revealed'),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: [
                  _PrimaryFieldCard(card: flashCard),
                  for (final (i, q) in flashCard.questions.indexed)
                    _revealQuestion(q, i),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : _WordCard(
              key: ValueKey('$_currentIndex-word'),
              card: flashCard,
              selectedResult: _currentCardData.primaryResult,
              onSelfEval: _setPrimaryResult,
              onMore: () => setState(() => _fullyRevealed = true),
              onNext: _next,
            ),
    );
  }

  // Persists a success/fail outcome for a question — fire-and-forget.
  // Key format: '{cardId}_{questionId}' — consistent across flash and workbook cards.
  void _recordQuestionResult(CardQuestion question, bool correct) {
    // Key by sequence position so each VISIT of a question scores once: a
    // re-queued card sits at a new position and counts again (a fresh
    // experience), while re-answering within one visit does not double-count.
    final key = '${_currentIndex}_${_currentCardId}_${question.questionId}';

    // Re-queue (#214): any wrong answer this visit marks the card as missed, so
    // it will be appended to the back of the queue when the user advances.
    if (!correct) _currentCardMissed = true;

    // Session score: count each question once per visit, on its first attempt.
    if (_countedQuestions.add(key)) {
      setState(() {
        _session = _session.copyWith(
          questionsTotal: _session.questionsTotal + 1,
          questionsCorrect: _session.questionsCorrect + (correct ? 1 : 0),
        );
      });
      _scheduleAutoSave();
    }

    // Global rolling-window history records every attempt (including retries).
    ref
        .read(questionResultRepositoryProvider)
        .recordResult(
          userId: _uid,
          cardId: _currentCardId,
          fieldId: '${_currentCardId}_${question.questionId}',
          fieldName: question.prompt ?? 'Question',
          fieldType: switch (question) {
            TextInputQuestion _ => AppConstants.fieldTypeTextInput,
            MultipleChoiceQuestion _ => AppConstants.fieldTypeMultipleChoice,
            WordOrderQuestion _ => AppConstants.questionTypeWordOrder,
            FillInTheBlanksQuestion _ => AppConstants.questionTypeFillInBlanks,
            GridQuestion _ => AppConstants.questionTypeGrid,
          },
          outcome: correct
              ? AppConstants.resultSuccess
              : AppConstants.resultFail,
        )
        .ignore();
  }

  // Animated workbook card view — mirrors the flash card AnimatedSwitcher.
  // Pre-reveal: prompt card with More/Next.  Post-reveal: all questions.
  Widget _buildWorkbookView(WorkbookCard card) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: (_fullyRevealed || card.questionAsCard)
          ? SingleChildScrollView(
              key: ValueKey('$_currentIndex-wb-revealed'),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: [
                  _WorkbookPromptHeader(card: card),
                  for (final (i, q) in card.questions.indexed)
                    _revealQuestion(q, i),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : _WorkbookPromptCard(
              key: ValueKey('$_currentIndex-wb-prompt'),
              card: card,
              onMore: () => setState(() => _fullyRevealed = true),
            ),
    );
  }

  // Progressive reveal (#215): wrap a question in a _QuestionReveal so later
  // questions stay collapsed to a label until their predecessor is answered.
  // The first question (and any whose predecessor is already answered) shows
  // fully; the full question widget is only built once expanded.
  Widget _revealQuestion(CardQuestion q, int index) {
    final expanded = isQuestionExpanded(index, _answeredQuestions);
    return _QuestionReveal(
      key: ValueKey(q.questionId),
      expanded: expanded,
      label: _questionLabel(q, index),
      child: expanded ? _buildQuestion(q, index) : null,
    );
  }

  // The label shown for a question — its own prompt, or a "Question N" default
  // (1-based) when the author left the prompt blank (#215). Used both for the
  // collapsed state and as the expanded question's header label.
  String _questionLabel(CardQuestion q, int index) {
    final p = q.prompt?.trim();
    return (p != null && p.isNotEmpty)
        ? p
        : context.l10n.labelQuestionNumber(index + 1);
  }

  // Records a question's result and advances the progressive reveal so the next
  // question expands. Reveal advances on ANY result (correct or not).
  void _onQuestionResult(CardQuestion q, int index, bool correct) {
    _recordQuestionResult(q, correct);
    if (_answeredQuestions.add(index)) setState(() {});
  }

  // Dispatch each question to its typed study widget — used for both flash
  // card questions and workbook card questions since they share CardQuestion.
  Widget _buildQuestion(CardQuestion q, int index) {
    final label = _questionLabel(q, index);
    return switch (q) {
      TextInputQuestion q => _WorkbookTextInputCard(
        question: q,
        labelOverride: label,
        onResult: (correct) => _onQuestionResult(q, index, correct),
      ),
      MultipleChoiceQuestion q => _WorkbookMultipleChoiceCard(
        question: q,
        labelOverride: label,
        onResult: (correct) => _onQuestionResult(q, index, correct),
      ),
      WordOrderQuestion q => _WordOrderCard(
        question: q,
        labelOverride: label,
        onResult: (correct) => _onQuestionResult(q, index, correct),
      ),
      FillInTheBlanksQuestion q => _FillInTheBlanksCard(
        question: q,
        labelOverride: label,
        onResult: (correct) => _onQuestionResult(q, index, correct),
      ),
      GridQuestion q => _GridCard(
        question: q,
        labelOverride: label,
        onResult: (correct) => _onQuestionResult(q, index, correct),
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// _WordCard — handles both the pre-reveal (word only) and translation-revealed
// (word + translation + self-eval + MORE + NEXT) states internally, so the
// primary word never moves.  AnimatedCrossFade fades the hint out and the
// translation in below the word — no widget swap, no AnimatedSwitcher flash.
// onSelfEval → parent records Knew it / Not yet for the recall portion.
// onMore     → parent triggers full slide-in reveal (additional fields).
// onNext     → parent advances to the next card (same as nav-bar arrow).
// selectedResult → the card's current primaryResult, to highlight the choice.
// ---------------------------------------------------------------------------
class _WordCard extends StatefulWidget {
  final FlashCard card;
  final String? selectedResult;
  final void Function(String result) onSelfEval;
  final VoidCallback onMore;
  final VoidCallback onNext;
  const _WordCard({
    super.key,
    required this.card,
    required this.selectedResult,
    required this.onSelfEval,
    required this.onMore,
    required this.onNext,
  });

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  late bool _wordVisible;
  bool _translationVisible = false;

  // Image cards reverse the study direction: the image + native word is the
  // cue, and the foreign word is what the user is trying to recall.
  bool get _isImageCard => widget.card.primaryImageUrl != null;
  String get _cueWord =>
      _isImageCard ? widget.card.translation : widget.card.primaryWord;
  String get _revealWord =>
      _isImageCard ? widget.card.primaryWord : widget.card.translation;

  @override
  void initState() {
    super.initState();
    _wordVisible = !widget.card.primaryWordHidden;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            onTapHint: _translationVisible
                ? null
                : _isImageCard
                ? context.l10n.semanticsRevealForeignWord
                : context.l10n.semanticsRevealTranslation,
            child: InkWell(
              // Tapping always reveals everything — even from the hidden state,
              // skipping the "Show Hint" step. Show Hint still works as a
              // halfway step if the user wants it.
              onTap: _translationVisible
                  ? null
                  : () => setState(() {
                      _wordVisible = true;
                      _translationVisible = true;
                    }),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (card.primaryImageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Image.network(
                            card.primaryImageUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, _, _) => SizedBox(
                              height: 80,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Theme.of(
                                    ctx,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!_wordVisible) ...[
                      Icon(
                        Icons.help_outline,
                        size: 56,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => setState(() => _wordVisible = true),
                        icon: const Icon(Icons.visibility_outlined),
                        // Image cards hide the native-word hint; text cards hide the foreign word.
                        label: Text(
                          _isImageCard
                              ? context.l10n.actionShowHint
                              : context.l10n.actionShowWord,
                        ),
                      ),
                    ] else ...[
                      // Cue word stays fixed; only the section below animates.
                      Text(
                        _cueWord,
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),

                      // "Tap to reveal" fades out; revealed word + buttons fade in.
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeOut,
                        firstChild: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_outlined,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.labelTapToReveal,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        secondChild: Column(
                          children: [
                            const Divider(height: 32),
                            Text(
                              _revealWord,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: scheme.primary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            // Row 1: self-evaluate recall. Selecting one highlights
                            // it and scores the card; the user advances via the
                            // nav arrow (no auto-advance), and may still tap More.
                            Row(
                              children: [
                                Expanded(
                                  child: _SelfEvalButton(
                                    label: context.l10n.labelKnewIt,
                                    icon: Icons.check,
                                    color: context.appColors.correct,
                                    selected:
                                        widget.selectedResult ==
                                        AppConstants.primaryResultKnown,
                                    onTap: () => widget.onSelfEval(
                                      AppConstants.primaryResultKnown,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SelfEvalButton(
                                    label: context.l10n.labelNotYet,
                                    icon: Icons.close,
                                    color: scheme.error,
                                    selected:
                                        widget.selectedResult ==
                                        AppConstants.primaryResultUnknown,
                                    onTap: () => widget.onSelfEval(
                                      AppConstants.primaryResultUnknown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Row 2: More enters full reveal — full-width, and
                            // only shown when the card has questions to answer.
                            if (widget.card.questions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: widget.onMore,
                                  child: Text(context.l10n.actionMore),
                                ),
                              ),
                            ],
                            // Row 3: Next — diminished treatment so the nav-bar
                            // arrow remains the primary advance gesture, but the
                            // button is reachable without moving the thumb.
                            const SizedBox(height: 12),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: widget.onNext,
                              child: Text(context.l10n.actionNextCard),
                            ),
                          ],
                        ),
                        crossFadeState: _translationVisible
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                      ),
                    ],
                  ],
                ),
              ),
            ), // InkWell
          ), // Semantics
        ), // Card
      ), // SingleChildScrollView
    ); // Center
  }
}

// ---------------------------------------------------------------------------
// _SelfEvalButton — Knew it / Not yet toggle shown after the reveal.
// Filled in its semantic colour when selected; outlined otherwise.
// Selecting scores the card; the user advances separately via the nav arrow.
// ---------------------------------------------------------------------------
class _SelfEvalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SelfEvalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      side: WidgetStatePropertyAll(BorderSide(color: color)),
      // Selected → solid colour fill with white content; idle → outlined.
      backgroundColor: WidgetStatePropertyAll(
        selected ? color : Colors.transparent,
      ),
      foregroundColor: WidgetStatePropertyAll(selected ? Colors.white : color),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PrimaryFieldCard — compact card at the top of the revealed list.
// Translation is always visible here since this widget only appears
// after the user has tapped to reveal.
// ---------------------------------------------------------------------------
class _PrimaryFieldCard extends StatelessWidget {
  final FlashCard card;
  const _PrimaryFieldCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Image cards: cue = translation (native), answer = primaryWord (foreign).
    final hasImage = card.primaryImageUrl != null;
    final topWord = hasImage ? card.translation : card.primaryWord;
    final bottomWord = hasImage ? card.primaryWord : card.translation;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.primaryImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.network(
                    card.primaryImageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, _, _) => SizedBox(
                      height: 60,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 32,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              topWord,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            Text(
              bottomWord,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NavigationBar — Previous / Next (→ Finish on last card) with a counter,
// plus Skip / Review marking buttons.
// ---------------------------------------------------------------------------
class _NavigationBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback onPrevious;
  // Also fires session completion when currentIndex == total - 1.
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onReview;
  final bool isMarkedSkip;
  final bool isMarkedReview;

  const _NavigationBar({
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.onReview,
    required this.isMarkedSkip,
    required this.isMarkedReview,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == total - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Review / Skip row ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MarkButton(
                label: context.l10n.actionReview,
                icon: Icons.flag_outlined,
                activeIcon: Icons.flag,
                isActive: isMarkedReview,
                activeColor: context.appColors.markReview,
                onTap: onReview,
                shortcutHint: 'U / 1',
              ),
              const SizedBox(width: 32),
              _MarkButton(
                label: context.l10n.actionSkip,
                icon: Icons.check_circle_outline,
                activeIcon: Icons.check_circle,
                isActive: isMarkedSkip,
                activeColor: context.appColors.markSkip,
                onTap: onSkip,
                shortcutHint: 'K / 2',
              ),
            ],
          ),

          // ── Previous / counter / Next ────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 32,
                // Desktop keyboard hint (#87) — a plain symbol, not a
                // sentence, so it doesn't need its own l10n entry.
                tooltip: '${context.l10n.tooltipPreviousCard} (←)',
                onPressed: currentIndex > 0 ? onPrevious : null,
              ),
              Expanded(
                // Semantic label reads as "Card X of Y" rather than "X / Y".
                child: Semantics(
                  label: context.l10n.semanticsCardOf(currentIndex + 1, total),
                  child: ExcludeSemantics(
                    child: Text(
                      context.l10n.labelCardProgress(currentIndex + 1, total),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
              IconButton(
                // On the last card, the icon becomes a check to signal Finish.
                icon: Icon(
                  isLast ? Icons.check_circle_outline : Icons.chevron_right,
                ),
                iconSize: 32,
                tooltip:
                    '${isLast ? context.l10n.tooltipFinishSession : context.l10n.tooltipNextCard} (→)',
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MarkButton — thumb-up / thumb-down button that fills in when active.
// Greyed out when canMark is false (card not yet revealed).
// ---------------------------------------------------------------------------
class _MarkButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  // Desktop keyboard hint (#87), e.g. 'K / 1' — shown as a hover tooltip.
  final String? shortcutHint;

  const _MarkButton({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
    this.shortcutHint,
  });

  @override
  State<_MarkButton> createState() => _MarkButtonState();
}

class _MarkButtonState extends State<_MarkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Active → semantic colour; disabled → dim; idle → muted
    final Color color;
    if (widget.isActive) {
      color = widget.activeColor;
    } else if (widget.onTap == null) {
      color = scheme.onSurface.withValues(alpha: 0.3);
    } else {
      color = scheme.onSurfaceVariant;
    }

    // Listener fires at pointer level without competing with TextButton's
    // gesture recogniser — used only for the press-scale visual.
    // Semantics.toggled announces the active/inactive state to screen readers.
    final button = Semantics(
      toggled: widget.isActive,
      child: Listener(
        onPointerDown: (_) {
          if (widget.onTap != null) setState(() => _pressed = true);
        },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: TextButton.icon(
            onPressed: widget.onTap,
            style: TextButton.styleFrom(
              foregroundColor: color,
              // Keep the active color visible even when disabled (post-reveal nav).
              disabledForegroundColor: color,
            ),
            icon: Icon(
              widget.isActive ? widget.activeIcon : widget.icon,
              color: color,
            ),
            label: Text(widget.label, style: TextStyle(color: color)),
          ),
        ),
      ), // Listener
    ); // Semantics
    return widget.shortcutHint == null
        ? button
        : Tooltip(message: widget.shortcutHint, child: button);
  }
}
