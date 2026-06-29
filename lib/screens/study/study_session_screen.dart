import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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
import 'package:flash_me/utils/transitions.dart';

// ---------------------------------------------------------------------------
// Haptic helpers — correct/incorrect feedback for answer results.
//
// On Android, HapticFeedback.lightImpact/mediumImpact use VibrationEffect
// predefined constants that some devices don't support. The vibration package
// calls Vibrator.vibrate(duration) directly, which is universally compatible.
// On iOS, the built-in HapticFeedback methods use UIImpactFeedbackGenerator
// and work correctly, so we keep them there.
// ---------------------------------------------------------------------------
void _hapticCorrect() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    Vibration.vibrate(duration: 40);
  } else {
    HapticFeedback.lightImpact();
  }
}

void _hapticIncorrect() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    Vibration.vibrate(duration: 80);
  } else {
    HapticFeedback.mediumImpact();
  }
}

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
  const StudySessionScreen(
      {super.key, required this.session, required this.cardSet});

  @override
  ConsumerState<StudySessionScreen> createState() =>
      _StudySessionScreenState();
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
  // score. Ensures first-attempt-only scoring — retries via "Try Again" and
  // re-answers after back-navigation don't re-count.
  final Set<String> _countedQuestions = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.session.currentCardIndex;
    _session = widget.session;
    // Ensure totalCardsStudied reflects at minimum the card currently on screen.
    final seen = _currentIndex + 1;
    if (seen > _session.totalCardsStudied) {
      _session = _session.copyWith(totalCardsStudied: seen);
    }
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
          flash =
              await ref.read(cardRepositoryProvider).getCardsByIds(flashIds, uid);
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

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _fullyRevealed = false;
        _session = _session.copyWith(currentCardIndex: _currentIndex);
      });
      _scheduleAutoSave();
    }
  }

  // On last card, Next triggers session completion instead of advancing.
  void _next() {
    if (_currentIndex < _total - 1) {
      final next = _currentIndex + 1;
      setState(() {
        _currentIndex = next;
        _fullyRevealed = false;
        _session = _session.copyWith(
          currentCardIndex: next,
          // High-water mark: only grows as the user navigates forward.
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
    updated[_currentCardId] =
        data.copyWith(markedKnown: newSkip, markedUnknown: newReview);

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
  // current card. Sets primaryResult and recomputes the session known/not-yet
  // tallies. Does not auto-advance — the user proceeds via the nav arrow, and
  // may still tap More to answer the card's questions afterwards.
  void _setPrimaryResult(String result) {
    HapticFeedback.selectionClick();
    final updated = Map<String, CardSessionData>.from(_session.cardProgress);
    updated[_currentCardId] = _currentCardData.copyWith(
      primaryResult: result,
      status: AppConstants.cardStatusAnswered,
    );

    // Recount from the full progress map. Workbook cards never set primaryResult,
    // so this is inherently flashcard-only.
    int known = 0, unknown = 0;
    for (final d in updated.values) {
      if (d.primaryResult == AppConstants.primaryResultKnown) {
        known++;
      } else if (d.primaryResult == AppConstants.primaryResultUnknown) {
        unknown++;
      }
    }

    setState(() {
      _session = _session.copyWith(
        cardProgress: updated,
        cardsKnown: known,
        cardsUnknown: unknown,
      );
    });
    _scheduleAutoSave();
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
    ref.read(studySessionRepositoryProvider)
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
    ref.read(studySessionRepositoryProvider)
        .completeSession(completed, _uid)
        .ignore();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        studySurfaceRoute(StudySessionSummaryScreen(
          session: completed,
          cardSet: widget.cardSet,
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _total,
          ),

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
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut)),
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
                  for (final q in flashCard.questions) _buildQuestion(q),
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
    final key = '${_currentCardId}_${question.questionId}';

    // Session score: count each question once, on its first attempt only.
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
    ref.read(questionResultRepositoryProvider).recordResult(
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
      outcome: correct ? AppConstants.resultSuccess : AppConstants.resultFail,
    ).ignore();
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
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: _fullyRevealed
          ? SingleChildScrollView(
              key: ValueKey('$_currentIndex-wb-revealed'),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: [
                  _WorkbookPromptHeader(card: card),
                  for (final q in card.questions)
                    _buildQuestion(q),
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

  // Dispatch each question to its typed study widget — used for both flash
  // card questions and workbook card questions since they share CardQuestion.
  Widget _buildQuestion(CardQuestion q) => switch (q) {
        TextInputQuestion q => _WorkbookTextInputCard(
            question: q,
            onResult: (correct) => _recordQuestionResult(q, correct),
          ),
        MultipleChoiceQuestion q => _WorkbookMultipleChoiceCard(
            question: q,
            onResult: (correct) => _recordQuestionResult(q, correct),
          ),
        WordOrderQuestion q => _WordOrderCard(
            question: q,
            onResult: (correct) => _recordQuestionResult(q, correct),
          ),
        FillInTheBlanksQuestion q => _FillInTheBlanksCard(
            question: q,
            onResult: (correct) => _recordQuestionResult(q, correct),
          ),
        GridQuestion q => _GridCard(
            question: q,
            onResult: (correct) => _recordQuestionResult(q, correct),
          ),
      };
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
                : _isImageCard ? context.l10n.semanticsRevealForeignWord : context.l10n.semanticsRevealTranslation,
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
                              child: Icon(Icons.broken_image_outlined,
                                  size: 40,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (!_wordVisible) ...[
                    Icon(Icons.help_outline,
                        size: 56, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          setState(() => _wordVisible = true),
                      icon: const Icon(Icons.visibility_outlined),
                      // Image cards hide the native-word hint; text cards hide the foreign word.
                      label: Text(_isImageCard ? context.l10n.actionShowHint : context.l10n.actionShowWord),
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
                            Icon(Icons.touch_app_outlined,
                                size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.labelTapToReveal,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
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
                                  selected: widget.selectedResult ==
                                      AppConstants.primaryResultKnown,
                                  onTap: () => widget.onSelfEval(
                                      AppConstants.primaryResultKnown),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SelfEvalButton(
                                  label: context.l10n.labelNotYet,
                                  icon: Icons.close,
                                  color: scheme.error,
                                  selected: widget.selectedResult ==
                                      AppConstants.primaryResultUnknown,
                                  onTap: () => widget.onSelfEval(
                                      AppConstants.primaryResultUnknown),
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
          ),        // InkWell
          ),        // Semantics
        ),          // Card
      ),            // SingleChildScrollView
    );              // Center
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
      backgroundColor:
          WidgetStatePropertyAll(selected ? color : Colors.transparent),
      foregroundColor:
          WidgetStatePropertyAll(selected ? Colors.white : color),
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
                        child: Icon(Icons.broken_image_outlined,
                            size: 32,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


enum _OptionState { neutral, correct, incorrect }

// Single option button with semantic colour coding post-answer.
class _OptionButton extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionButton(
      {required this.label, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color border;
    final Color fg;

    final appColors = context.appColors;
    switch (state) {
      case _OptionState.correct:
        bg = appColors.correctSurface;
        border = appColors.correct;
        fg = appColors.onCorrectSurface;
      case _OptionState.incorrect:
        bg = scheme.errorContainer.withValues(alpha: 0.5);
        border = scheme.error;
        fg = scheme.error;
      case _OptionState.neutral:
        bg = Colors.transparent;
        border = scheme.outline;
        fg = scheme.onSurface;
    }

    // Announce the result state to screen readers when it changes.
    final stateLabel = switch (state) {
      _OptionState.correct => context.l10n.semanticsOptionCorrect,
      _OptionState.incorrect => context.l10n.semanticsOptionIncorrect,
      _OptionState.neutral => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '$label$stateLabel',
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: bg,
              side: BorderSide(color: border),
              foregroundColor: fg,
              // Override disabled colours so the result highlight stays visible.
              disabledForegroundColor: fg,
              disabledBackgroundColor: bg,
              alignment: Alignment.centerLeft,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(label),
          ),
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
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
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
              ),
              const SizedBox(width: 32),
              _MarkButton(
                label: context.l10n.actionSkip,
                icon: Icons.check_circle_outline,
                activeIcon: Icons.check_circle,
                isActive: isMarkedSkip,
                activeColor: context.appColors.markSkip,
                onTap: onSkip,
              ),
            ],
          ),

          // ── Previous / counter / Next ────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 32,
                tooltip: context.l10n.tooltipPreviousCard,
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
                icon: Icon(isLast ? Icons.check_circle_outline : Icons.chevron_right),
                iconSize: 32,
                tooltip: isLast ? context.l10n.tooltipFinishSession : context.l10n.tooltipNextCard,
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

  const _MarkButton({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
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
    return Semantics(
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
          icon: Icon(widget.isActive ? widget.activeIcon : widget.icon, color: color),
          label: Text(widget.label, style: TextStyle(color: color)),
        ),
      ),
    ),    // Listener
    );    // Semantics
  }
}

// ---------------------------------------------------------------------------
// _FieldLabel — shared field-name label used by all additional field cards.
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String name;
  const _FieldLabel({required this.name});

  @override
  Widget build(BuildContext context) => Text(
        name,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

// ===========================================================================
// Workbook card widgets
// ===========================================================================

// ---------------------------------------------------------------------------
// _WorkbookPromptCard — pre-reveal state for a workbook card.
// Shows the prompt text and question count; More enters the questions phase.
// Advancing without engaging is done via the nav arrow (no Next button).
// ---------------------------------------------------------------------------
class _WorkbookPromptCard extends StatelessWidget {
  final WorkbookCard card;
  final VoidCallback onMore;
  const _WorkbookPromptCard(
      {super.key, required this.card, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qCount = card.questions.length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book_outlined, size: 40, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  card.prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.labelQuestionCount(qCount),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: onMore, child: Text(context.l10n.actionMore)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WorkbookPromptHeader — compact prompt row at the top of the revealed view.
// ---------------------------------------------------------------------------
class _WorkbookPromptHeader extends StatelessWidget {
  final WorkbookCard card;
  const _WorkbookPromptHeader({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.book_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                card.prompt,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WorkbookTextInputCard — text-input question in the workbook study view.
// Same validation logic as _TextInputFieldCard but keyed to WorkbookQuestion.
// ---------------------------------------------------------------------------
class _WorkbookTextInputCard extends StatefulWidget {
  final TextInputQuestion question;
  final void Function(bool correct)? onResult;
  const _WorkbookTextInputCard({required this.question, this.onResult});

  @override
  State<_WorkbookTextInputCard> createState() => _WorkbookTextInputCardState();
}

class _WorkbookTextInputCardState extends State<_WorkbookTextInputCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  AnswerResult? _result;
  // Canonical form of the first accepted answer (for "correct form" hint).
  String? _matchedAnswer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final answers = widget.question.correctAnswers ?? [];
    // Scan accepted answers — prefer an exact normalised match over a close one.
    AnswerResult best = AnswerResult.incorrect;
    String? matched;
    for (final a in answers) {
      final r = AppHelpers.checkAnswer(input, [a],
          exact: widget.question.exactMatch);
      if (r == AnswerResult.correct) { best = r; matched = a; break; }
      if (r == AnswerResult.close && best == AnswerResult.incorrect) {
        best = r; matched = a;
      }
    }
    setState(() { _result = best; _matchedAnswer = matched; });
    best != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(best != AnswerResult.incorrect);
  }

  void _tryAgain() {
    setState(() {
      _controller.clear();
      _result = null;
      _matchedAnswer = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final cardColor = answered
        ? (isAccepted
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.4))
        : null;
    final prompt = widget.question.prompt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 8),
            ],
            if (widget.question.hint != null) ...[
              Text(
                widget.question.hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !answered,
                    textInputAction: TextInputAction.done,
                    onSubmitted: answered ? null : (_) => _check(),
                    decoration: InputDecoration(
                      hintText: context.l10n.hintTypeYourAnswer,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _check, child: Text(context.l10n.actionCheck)),
                ],
              ],
            ),
            if (answered) ...[
              const SizedBox(height: 10),
              if (isAccepted) ...[
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      color: appColors.onCorrectSurface, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    FeedbackPhrases.forResult(_result!, context.l10n),
                    style: TextStyle(
                        color: appColors.onCorrectSurface,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                // Show canonical spelling whenever the user's input differed —
                // covers both diacritic differences and close (fuzzy) matches.
                if (_matchedAnswer != null &&
                    _matchedAnswer != _controller.text.trim()) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.messageCorrectForm(_matchedAnswer!),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ] else ...[
                Row(children: [
                  Icon(Icons.cancel_outlined,
                      color: scheme.error, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      FeedbackPhrases.forResult(_result!, context.l10n),
                      style: TextStyle(
                          color: scheme.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                      onPressed: _tryAgain,
                      child: Text(context.l10n.actionTryAgain)),
                ]),
                const SizedBox(height: 4),
                Text(
                  context.l10n.messageAnswerReveal(
                      (widget.question.correctAnswers ?? []).join(' / ')),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WorkbookMultipleChoiceCard — MC question with list or chips display mode.
// ---------------------------------------------------------------------------
class _WorkbookMultipleChoiceCard extends StatefulWidget {
  final MultipleChoiceQuestion question;
  final void Function(bool correct)? onResult;
  const _WorkbookMultipleChoiceCard(
      {required this.question, this.onResult});

  @override
  State<_WorkbookMultipleChoiceCard> createState() =>
      _WorkbookMultipleChoiceCardState();
}

class _WorkbookMultipleChoiceCardState
    extends State<_WorkbookMultipleChoiceCard> {
  int? _selectedIndex;
  late final List<String> _displayOptions;
  late final int? _displayCorrectIndex;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    final original = q.options ?? [];
    if (q.randomizeOptions && original.isNotEmpty) {
      // Zip each option with its original index, shuffle, then split back.
      // This lets us find where the correct answer landed after the shuffle.
      final indexed = original.asMap().entries.toList()..shuffle();
      _displayOptions = indexed.map((e) => e.value).toList();
      _displayCorrectIndex = q.correctIndex == null
          ? null
          : indexed.indexWhere((e) => e.key == q.correctIndex);
    } else {
      _displayOptions = original;
      _displayCorrectIndex = q.correctIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = _displayOptions;
    final correctIndex = _displayCorrectIndex;
    final answered = _selectedIndex != null;
    final prompt = widget.question.prompt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // Chips mode: compact wrapping chip row.
            if (widget.question.displayMode == MultipleChoiceDisplayMode.chips)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < options.length; i++)
                    _OptionButton(
                      label: options[i],
                      state: _stateFor(i, correctIndex, answered),
                      onTap: answered
                          ? null
                          : () {
                              final correct = i == correctIndex;
                              setState(() => _selectedIndex = i);
                              correct
                                  ? _hapticCorrect()
                                  : _hapticIncorrect();
                              widget.onResult?.call(correct);
                            },
                    ),
                ],
              )
            // List mode: full-width vertical buttons (default).
            else
              for (var i = 0; i < options.length; i++)
                _OptionButton(
                  label: options[i],
                  state: _stateFor(i, correctIndex, answered),
                  onTap: answered
                      ? null
                      : () {
                          final correct = i == correctIndex;
                          setState(() => _selectedIndex = i);
                          correct ? _hapticCorrect() : _hapticIncorrect();
                          widget.onResult?.call(correct);
                        },
                ),

            if (answered && widget.question.explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.question.explanation!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _OptionState _stateFor(int i, int? correctIndex, bool answered) {
    if (!answered) return _OptionState.neutral;
    if (i == correctIndex) return _OptionState.correct;
    if (i == _selectedIndex) return _OptionState.incorrect;
    return _OptionState.neutral;
  }
}

// ---------------------------------------------------------------------------
// _WordOrderCard — word order question.
// Available tiles sit in the bank row; tap to place in the answer row.
// Tap a placed tile to return it to the bank.  Check validates the order.
// ---------------------------------------------------------------------------
class _WordOrderCard extends StatefulWidget {
  final WordOrderQuestion question;
  final void Function(bool correct)? onResult;
  const _WordOrderCard({required this.question, this.onResult});

  @override
  State<_WordOrderCard> createState() => _WordOrderCardState();
}

class _WordOrderCardState extends State<_WordOrderCard> {
  late List<String> _available;
  final List<String> _placed = [];
  bool? _result;

  @override
  void initState() {
    super.initState();
    _available = List.from(widget.question.wordBank ?? []);
  }

  void _placeTile(int index) {
    if (_result != null) return;
    setState(() => _placed.add(_available.removeAt(index)));
  }

  void _returnTile(int index) {
    if (_result != null) return;
    setState(() => _available.add(_placed.removeAt(index)));
  }

  void _check() {
    final correct = _ordersEqual(_placed, widget.question.correctOrder ?? []);
    setState(() => _result = correct);
    correct ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(correct);
  }

  void _tryAgain() {
    setState(() {
      _available = List.from(widget.question.wordBank ?? []);
      _placed.clear();
      _result = null;
    });
  }

  bool _ordersEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isCorrect = _result == true;
    final prompt = widget.question.prompt;

    final cardColor = answered
        ? (isCorrect
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.4))
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // Answer row — placed tiles; tap to return to bank.
            Text(context.l10n.labelYourAnswer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _placed.isEmpty
                  ? Text(
                      context.l10n.labelTapWordsToBuild,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _placed.asMap().entries.map((e) {
                        return ActionChip(
                          label: Text(e.value),
                          onPressed:
                              answered ? null : () => _returnTile(e.key),
                          visualDensity: VisualDensity.compact,
                          tooltip: context.l10n.tooltipTapToReturn,
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),

            // Word bank — available tiles; tap to place.
            Text(context.l10n.labelWordBank,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _available.asMap().entries.map((e) {
                return ActionChip(
                  label: Text(e.value),
                  onPressed: answered ? null : () => _placeTile(e.key),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Check / feedback row.
            if (!answered)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed:
                      _placed.isEmpty ? null : _check,
                  child: Text(context.l10n.actionCheck),
                ),
              )
            else if (isCorrect)
              Row(children: [
                Icon(Icons.check_circle_outline,
                    color: appColors.onCorrectSurface, size: 20),
                const SizedBox(width: 6),
                Text(context.l10n.labelCorrect,
                    style: TextStyle(
                        color: appColors.onCorrectSurface,
                        fontWeight: FontWeight.bold)),
              ])
            else ...[
              Row(children: [
                Icon(Icons.cancel_outlined,
                    color: scheme.error, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(context.l10n.labelIncorrect,
                      style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                    onPressed: _tryAgain,
                    child: Text(context.l10n.actionTryAgain)),
              ]),
              const SizedBox(height: 4),
              Text(
                context.l10n.messageAnswerReveal((widget.question.correctOrder ?? []).join(' ')),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FillInTheBlanksCard — fill-in-the-blanks question (#170), pill tap-to-fill.
//
// The sentence is rendered inline with `blankCount` randomly-chosen eligible
// words replaced by tappable slots.  A word pool below holds the blanked words
// plus author distractors.  Tap a blank to select it, then tap a pool word to
// drop it in (tap a filled blank to return its word).  Check grades each slot
// by exact word match — pool words are the exact answers, so identity match is
// correct.  Text-input completion mode is deferred to the #168 normalisation
// pass; until then authoring only offers pill mode, so this widget always
// renders pill mode.
// ---------------------------------------------------------------------------
class _FillInTheBlanksCard extends StatefulWidget {
  final FillInTheBlanksQuestion question;
  final void Function(bool correct)? onResult;
  const _FillInTheBlanksCard({required this.question, this.onResult});

  @override
  State<_FillInTheBlanksCard> createState() => _FillInTheBlanksCardState();
}

class _FillInTheBlanksCardState extends State<_FillInTheBlanksCard> {
  late List<FillBlankToken> _tokens;
  late List<int> _blankIndices; // token indices that are blanks (reading order)
  late Set<int> _blankSet;      // same, for fast lookup during render
  late List<String> _pool;      // pool words (blanked words + distractors)
  final Map<int, int> _placement = {}; // blankTokenIndex -> pool index
  int? _selectedBlank;          // blank currently selected to fill
  AnswerResult? _result;
  // Text-input mode: one controller per blank token index.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _tokens = widget.question.tokens ?? [];
    _setupRound();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  // Randomly pick which eligible words to blank, then build the shuffled pool.
  void _setupRound() {
    final eligible = <int>[];
    for (var i = 0; i < _tokens.length; i++) {
      if (_tokens[i].eligible) { eligible.add(i); }
    }
    eligible.shuffle();
    final count = widget.question.blankCount.clamp(0, eligible.length);
    _blankIndices = eligible.take(count).toList()..sort();
    _blankSet = _blankIndices.toSet();
    _pool = [
      ..._blankIndices.map((i) => _tokens[i].word),
      ...widget.question.extraWords,
    ]..shuffle();
    _placement.clear();
    _selectedBlank = _blankIndices.isNotEmpty ? _blankIndices.first : null;
    _result = null;
    // Text-input mode: create one controller per blank; dispose any previous.
    for (final c in _textControllers.values) { c.dispose(); }
    _textControllers.clear();
    if (widget.question.completionMode == CompletionMode.textInput) {
      for (final i in _blankIndices) {
        _textControllers[i] = TextEditingController();
      }
    }
  }

  Set<int> get _usedPoolIds => _placement.values.toSet();
  bool get _allFilled => _placement.length == _blankIndices.length;
  // Text-input mode: every blank has a non-empty entry.
  bool get _allTextFilled => _blankIndices.every(
      (i) => (_textControllers[i]?.text ?? '').trim().isNotEmpty);

  int? _firstEmptyBlank() {
    for (final b in _blankIndices) {
      if (!_placement.containsKey(b)) return b;
    }
    return null;
  }

  // Place a pool word into the selected (or next empty) blank.
  void _onPoolTap(int poolId) {
    if (_result != null || _usedPoolIds.contains(poolId)) return;
    final sel = _selectedBlank;
    final target =
        (sel != null && !_placement.containsKey(sel)) ? sel : _firstEmptyBlank();
    if (target == null) return;
    setState(() {
      _placement[target] = poolId;
      _selectedBlank = _firstEmptyBlank();
    });
  }

  // Tap a blank: return its word to the pool if filled, then select it.
  void _onBlankTap(int tokenIndex) {
    if (_result != null) return;
    setState(() {
      _placement.remove(tokenIndex);
      _selectedBlank = tokenIndex;
    });
  }

  void _check() {
    if (widget.question.completionMode == CompletionMode.textInput) {
      // Text-input mode: tri-state — any incorrect slot → incorrect;
      // all accepted with at least one close → close; all exact → correct.
      var result = AnswerResult.correct;
      for (final b in _blankIndices) {
        final r = AppHelpers.checkAnswer(
            _textControllers[b]?.text ?? '', [_tokens[b].word]);
        if (r == AnswerResult.incorrect) { result = AnswerResult.incorrect; break; }
        if (r == AnswerResult.close) result = AnswerResult.close;
      }
      setState(() => _result = result);
      result != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
      widget.onResult?.call(result != AnswerResult.incorrect);
      return;
    }
    // Pill mode: exact match of placed pool word — correct or incorrect only.
    var allCorrect = true;
    for (final b in _blankIndices) {
      final poolId = _placement[b];
      final placedWord = poolId != null ? _pool[poolId] : null;
      if (placedWord != _tokens[b].word) { allCorrect = false; break; }
    }
    final result = allCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    setState(() => _result = result);
    allCorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(allCorrect);
  }

  void _tryAgain() {
    for (final c in _textControllers.values) { c.clear(); }
    setState(() {
      _placement.clear();
      _selectedBlank = _blankIndices.isNotEmpty ? _blankIndices.first : null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final prompt = widget.question.prompt;

    final cardColor = answered
        ? (isAccepted
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.4))
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // Sentence with inline blank slots (pill or text-input).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _tokens.length; i++)
                  if (_blankSet.contains(i))
                    _affixed(
                      _tokens[i],
                      widget.question.completionMode == CompletionMode.textInput
                          ? _buildTextSlot(i, scheme, appColors)
                          : _buildSlot(i, scheme, appColors),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                          '${_tokens[i].leading}${_tokens[i].word}${_tokens[i].trailing}',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
              ],
            ),
            const SizedBox(height: 16),

            // Word pool — pill mode only, hidden once answered.
            if (widget.question.completionMode == CompletionMode.pill &&
                !answered) ...[
              Text(context.l10n.labelWordBank,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var p = 0; p < _pool.length; p++)
                    if (!_usedPoolIds.contains(p))
                      ActionChip(
                        label: Text(_pool[p]),
                        onPressed: () => _onPoolTap(p),
                        visualDensity: VisualDensity.compact,
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Check / feedback row.
            if (!answered)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: (widget.question.completionMode ==
                              CompletionMode.textInput
                          ? _allTextFilled
                          : _allFilled)
                      ? _check
                      : null,
                  child: Text(context.l10n.actionCheck),
                ),
              )
            else if (isAccepted)
              Row(children: [
                Icon(Icons.check_circle_outline,
                    color: appColors.onCorrectSurface, size: 20),
                const SizedBox(width: 6),
                Text(
                  FeedbackPhrases.forResult(_result!, context.l10n),
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.bold),
                ),
              ])
            else ...[
              Row(children: [
                Icon(Icons.cancel_outlined, color: scheme.error, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    FeedbackPhrases.forResult(_result!, context.l10n),
                    style: TextStyle(
                        color: scheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                    onPressed: _tryAgain,
                    child: Text(context.l10n.actionTryAgain)),
              ]),
              const SizedBox(height: 4),
              Text(
                context.l10n.messageAnswerReveal(widget.question.sentence ?? ''),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Wrap a blank slot with its leading/trailing punctuation so the marks hug
  // the slot (e.g. ¿___? ) rather than floating with the Wrap's word spacing.
  Widget _affixed(FillBlankToken token, Widget slot) {
    if (token.leading.isEmpty && token.trailing.isEmpty) return slot;
    final style = Theme.of(context).textTheme.bodyLarge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (token.leading.isNotEmpty) Text(token.leading, style: style),
        slot,
        if (token.trailing.isNotEmpty) Text(token.trailing, style: style),
      ],
    );
  }

  // One inline blank slot: empty/selected/filled before checking; green/red
  // (with the correct word) after.
  Widget _buildSlot(int tokenIndex, ColorScheme scheme, AppColors appColors) {
    final poolId = _placement[tokenIndex];
    final placedWord = poolId != null ? _pool[poolId] : null;
    final answered = _result != null;

    if (answered) {
      final correctWord = _tokens[tokenIndex].word;
      if (placedWord == correctWord) {
        return _slotChip(
            text: correctWord,
            bg: appColors.correctSurface,
            fg: appColors.onCorrectSurface);
      }
      // Wrong: user's word struck through, followed by the correct word.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _slotChip(
                text: placedWord ?? '—',
                bg: scheme.errorContainer,
                fg: scheme.onErrorContainer,
                strike: true),
            _slotChip(
                text: correctWord,
                bg: appColors.correctSurface,
                fg: appColors.onCorrectSurface),
          ],
        ),
      );
    }

    final selected = _selectedBlank == tokenIndex;
    return GestureDetector(
      onTap: () => _onBlankTap(tokenIndex),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: placedWord != null ? scheme.secondaryContainer : null,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          placedWord ?? '   ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: placedWord != null
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  // Text-input slot: a compact inline TextField while unanswered; switches to
  // a coloured chip showing the CANONICAL correct word (not the user's input)
  // on reveal so the learner always sees the right form.
  Widget _buildTextSlot(int tokenIndex, ColorScheme scheme, AppColors appColors) {
    final correctWord = _tokens[tokenIndex].word;
    final answered = _result != null;

    if (answered) {
      final input = _textControllers[tokenIndex]?.text ?? '';
      final inputTrim = input.trim();
      final correct = AppHelpers.isAnswerCorrect(inputTrim, [correctWord]);
      // Was the answer typed exactly, or accepted via tolerance (case /
      // diacritic / typo)? A close acceptance still shows the canonical form.
      final exact = correct && inputTrim == correctWord;

      // Clean exact entry → single correct chip.
      if (exact) {
        return _slotChip(
            text: correctWord,
            bg: appColors.correctSurface,
            fg: appColors.onCorrectSurface);
      }

      // Close acceptance → show the user's entry (neutral, not struck) next to
      // the canonical form so they see what the right spelling was.
      if (correct) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _slotChip(
                  text: inputTrim.isEmpty ? '—' : inputTrim,
                  bg: scheme.secondaryContainer,
                  fg: scheme.onSecondaryContainer),
              _slotChip(
                  text: correctWord,
                  bg: appColors.correctSurface,
                  fg: appColors.onCorrectSurface),
            ],
          ),
        );
      }

      // Incorrect → struck-through entry next to the correct form.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _slotChip(
                text: inputTrim.isEmpty ? '—' : inputTrim,
                bg: scheme.errorContainer,
                fg: scheme.onErrorContainer,
                strike: true),
            _slotChip(
                text: correctWord,
                bg: appColors.correctSurface,
                fg: appColors.onCorrectSurface),
          ],
        ),
      );
    }

    // Active: a small inline text field sized to the expected word length.
    final approxWidth = (correctWord.length * 11.0).clamp(52.0, 130.0);
    return SizedBox(
      width: approxWidth,
      child: TextField(
        controller: _textControllers[tokenIndex],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        style: Theme.of(context).textTheme.bodyLarge,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}), // recheck _allTextFilled
      ),
    );
  }

  Widget _slotChip(
      {required String text,
      required Color bg,
      required Color fg,
      bool strike = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              decoration: strike ? TextDecoration.lineThrough : null)),
    );
  }
}

// ---------------------------------------------------------------------------
// _GridCard — complete-the-grid question (#167), pill tap-to-fill.
//
// The table is rendered with optional row/column headers; `emptyCount` cells
// are randomly hidden as tappable slots.  A pool below holds the hidden cell
// values.  Tap a slot to select it, then tap a pool word to drop it in (tap a
// filled slot to return its word).  Check grades each slot by exact match —
// pool words are the exact cell values, so identity match is correct.  Cells
// are addressed by a linear index (row * columnCount + col).  Text-input mode
// is deferred to the #168 pass; authoring only offers pill mode for now.
// ---------------------------------------------------------------------------
class _GridCard extends StatefulWidget {
  final GridQuestion question;
  final void Function(bool correct)? onResult;
  const _GridCard({required this.question, this.onResult});

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  late List<List<String>> _cells;
  late int _cols;
  late List<int> _hiddenOrder; // hidden linear indices, reading order
  late Set<int> _hiddenSet;
  late List<String> _pool;
  final Map<int, int> _placement = {}; // hidden linear index -> pool index
  int? _selectedCell;
  AnswerResult? _result;
  // Text-input mode: one controller per hidden linear cell index.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _cells = widget.question.cells ?? const [];
    _cols = widget.question.columnCount;
    _setupRound();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  // Randomly choose which cells to hide, then build the shuffled pool.
  void _setupRound() {
    final total = _cells.length * _cols;
    final all = List<int>.generate(total, (i) => i)..shuffle();
    final count = widget.question.emptyCount.clamp(0, total);
    _hiddenOrder = all.take(count).toList()..sort();
    _hiddenSet = _hiddenOrder.toSet();
    _pool = [
      ..._hiddenOrder.map((idx) => _cells[idx ~/ _cols][idx % _cols]),
      ...widget.question.extraWords,
    ]..shuffle();
    _placement.clear();
    _selectedCell = _hiddenOrder.isNotEmpty ? _hiddenOrder.first : null;
    _result = null;
    // Text-input mode: create one controller per hidden cell; dispose previous.
    for (final c in _textControllers.values) { c.dispose(); }
    _textControllers.clear();
    if (widget.question.completionMode == CompletionMode.textInput) {
      for (final idx in _hiddenOrder) {
        _textControllers[idx] = TextEditingController();
      }
    }
  }

  Set<int> get _usedPoolIds => _placement.values.toSet();
  bool get _allFilled => _placement.length == _hiddenOrder.length;
  bool get _allTextFilled => _hiddenOrder.every(
      (i) => (_textControllers[i]?.text ?? '').trim().isNotEmpty);

  int? _firstEmptyCell() {
    for (final c in _hiddenOrder) {
      if (!_placement.containsKey(c)) return c;
    }
    return null;
  }

  void _onPoolTap(int poolId) {
    if (_result != null || _usedPoolIds.contains(poolId)) return;
    final sel = _selectedCell;
    final target =
        (sel != null && !_placement.containsKey(sel)) ? sel : _firstEmptyCell();
    if (target == null) return;
    setState(() {
      _placement[target] = poolId;
      _selectedCell = _firstEmptyCell();
    });
  }

  void _onCellTap(int linearIndex) {
    if (_result != null) return;
    setState(() {
      _placement.remove(linearIndex);
      _selectedCell = linearIndex;
    });
  }

  void _check() {
    if (widget.question.completionMode == CompletionMode.textInput) {
      var result = AnswerResult.correct;
      for (final idx in _hiddenOrder) {
        final r = AppHelpers.checkAnswer(
            _textControllers[idx]?.text ?? '',
            [_cells[idx ~/ _cols][idx % _cols]]);
        if (r == AnswerResult.incorrect) { result = AnswerResult.incorrect; break; }
        if (r == AnswerResult.close) result = AnswerResult.close;
      }
      setState(() => _result = result);
      result != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
      widget.onResult?.call(result != AnswerResult.incorrect);
      return;
    }
    var allCorrect = true;
    for (final idx in _hiddenOrder) {
      final poolId = _placement[idx];
      final placed = poolId != null ? _pool[poolId] : null;
      if (placed != _cells[idx ~/ _cols][idx % _cols]) { allCorrect = false; break; }
    }
    final result = allCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    setState(() => _result = result);
    allCorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(allCorrect);
  }

  void _tryAgain() {
    for (final c in _textControllers.values) { c.clear(); }
    setState(() {
      _placement.clear();
      _selectedCell = _hiddenOrder.isNotEmpty ? _hiddenOrder.first : null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final prompt = widget.question.prompt;
    final q = widget.question;
    final hasRowHeaders = q.rowHeaders.isNotEmpty;
    final hasColHeaders = q.columnHeaders.isNotEmpty;

    final cardColor = answered
        ? (isAccepted
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.4))
        : null;

    // Build the table rows.
    final tableRows = <TableRow>[];
    if (hasColHeaders) {
      tableRows.add(TableRow(children: [
        if (hasRowHeaders)
          _headerCell(q.cornerLabel, scheme), // top-left corner label
        for (final h in q.columnHeaders) _headerCell(h, scheme),
      ]));
    }
    for (var r = 0; r < _cells.length; r++) {
      tableRows.add(TableRow(children: [
        if (hasRowHeaders)
          _headerCell(r < q.rowHeaders.length ? q.rowHeaders[r] : '', scheme),
        for (var c = 0; c < _cols; c++)
          _dataCell(r * _cols + c, scheme, appColors),
      ]));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // The grid — centred; IntrinsicWidth makes the Table shrink-wrap to
            // its content so Center can position it rather than filling width.
            Center(
              child: IntrinsicWidth(
                child: Table(
                  border: TableBorder.all(color: scheme.outlineVariant),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: tableRows,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Word pool — pill mode only, hidden once answered.
            if (widget.question.completionMode == CompletionMode.pill &&
                !answered) ...[
              Text(context.l10n.labelWordBank,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var p = 0; p < _pool.length; p++)
                    if (!_usedPoolIds.contains(p))
                      ActionChip(
                        label: Text(_pool[p]),
                        onPressed: () => _onPoolTap(p),
                        visualDensity: VisualDensity.compact,
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Check / feedback row.
            if (!answered)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: (widget.question.completionMode ==
                              CompletionMode.textInput
                          ? _allTextFilled
                          : _allFilled)
                      ? _check
                      : null,
                  child: Text(context.l10n.actionCheck),
                ),
              )
            else if (isAccepted)
              Row(children: [
                Icon(Icons.check_circle_outline,
                    color: appColors.onCorrectSurface, size: 20),
                const SizedBox(width: 6),
                Text(
                  FeedbackPhrases.forResult(_result!, context.l10n),
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.bold),
                ),
              ])
            else
              Row(children: [
                Icon(Icons.cancel_outlined, color: scheme.error, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    FeedbackPhrases.forResult(_result!, context.l10n),
                    style: TextStyle(
                        color: scheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                    onPressed: _tryAgain,
                    child: Text(context.l10n.actionTryAgain)),
              ]),
          ],
        ),
      ),
    );
  }

  // Header cells fill the row height (TableCellVerticalAlignment.fill) so the
  // grey background covers the whole cell — otherwise, when a sibling data cell
  // grows tall (a wrong entry stacked above its correct value), the card's
  // result tint would bleed through the gap. Data cells stay middle-aligned,
  // which gives the row its intrinsic height.
  Widget _headerCell(String text, ColorScheme scheme) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.fill,
        child: Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );

  // A grid data cell: fixed value when visible; pill slot or text field when
  // hidden, depending on completionMode.
  Widget _dataCell(int linearIndex, ColorScheme scheme, AppColors appColors) {
    final value = _cells[linearIndex ~/ _cols][linearIndex % _cols];

    if (!_hiddenSet.contains(linearIndex)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final answered = _result != null;

    // ── Text-input mode ────────────────────────────────────────────────────
    if (widget.question.completionMode == CompletionMode.textInput) {
      if (answered) {
        final input = _textControllers[linearIndex]?.text ?? '';
        final inputTrim = input.trim();
        final correct = AppHelpers.isAnswerCorrect(inputTrim, [value]);
        // Exact typed vs accepted-via-tolerance (case / diacritic / typo).
        final exact = correct && inputTrim == value;
        // Show the user's entry above the canonical form whenever it differs —
        // struck through if wrong, neutral if a close acceptance.
        final showEntry = !exact;
        return Container(
          color: correct
              ? appColors.correctSurface
              : scheme.errorContainer.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showEntry)
                Text(inputTrim.isEmpty ? '—' : inputTrim,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: correct
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                        fontWeight: FontWeight.w600,
                        decoration:
                            correct ? null : TextDecoration.lineThrough)),
              Text(value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }
      // Active text field sized to expected content.
      final approxWidth = (value.length * 11.0).clamp(52.0, 110.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SizedBox(
          width: approxWidth,
          child: TextField(
            controller: _textControllers[linearIndex],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}), // recheck _allTextFilled
          ),
        ),
      );
    }

    // ── Pill (tap-to-fill) mode ────────────────────────────────────────────
    final poolId = _placement[linearIndex];
    final placed = poolId != null ? _pool[poolId] : null;

    if (answered) {
      final correct = placed == value;
      return Container(
        color: correct
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(placed ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: correct ? appColors.onCorrectSurface : scheme.error,
                  fontWeight: FontWeight.w600,
                  decoration: correct ? null : TextDecoration.lineThrough,
                )),
            if (!correct)
              Text(value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final selected = _selectedCell == linearIndex;
    return GestureDetector(
      onTap: () => _onCellTap(linearIndex),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 36),
        alignment: Alignment.center,
        color: selected
            ? scheme.primaryContainer
            : (placed != null ? scheme.secondaryContainer : null),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          placed ?? '____',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: placed != null
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
