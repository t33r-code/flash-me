import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_mark_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/question_result_provider.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/screens/study/study_session_summary_screen.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/transitions.dart';

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

  // Workbook cards fetched once on init; keyed by card ID.
  Map<String, WorkbookCard> _workbookCardsMap = {};
  // True after the workbook card fetch completes (or if there are none to fetch).
  bool _workbookCardsLoaded = false;

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
    _loadWorkbookCards();
  }

  // Fetches all workbook cards referenced by this session in one batch.
  Future<void> _loadWorkbookCards() async {
    final workbookIds = _session.cardTypeMap.entries
        .where((e) => e.value == AppConstants.cardTypeWorkbook)
        .map((e) => e.key)
        .toList();
    if (workbookIds.isEmpty) {
      if (mounted) setState(() => _workbookCardsLoaded = true);
      return;
    }
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final cards = await ref
          .read(workbookCardRepositoryProvider)
          .getCardsByIds(workbookIds, uid);
      if (mounted) {
        setState(() {
          _workbookCardsMap = {for (final c in cards) c.id: c};
          _workbookCardsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _workbookCardsLoaded = true);
    }
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
    if (!_fullyRevealed) return;
    final data = _currentCardData;
    final wasActive = markSkip ? data.markedKnown : data.markedUnknown;

    final newSkip = markSkip ? !wasActive : false;
    final newReview = !markSkip ? !wasActive : false;

    final updated = Map<String, CardSessionData>.from(_session.cardProgress);
    updated[_currentCardId] =
        data.copyWith(markedKnown: newSkip, markedUnknown: newReview);

    // Recount totals from the full progress map after the change.
    int known = 0, unknown = 0;
    for (final d in updated.values) {
      if (d.markedKnown) known++;
      if (d.markedUnknown) unknown++;
    }

    setState(() {
      _session = _session.copyWith(
        cardProgress: updated,
        cardsKnown: known,
        cardsUnknown: unknown,
      );
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

  // Cancel any pending save and restart the countdown.
  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), _saveNow);
  }

  // Writes the current session to Firestore.
  // On failure: shows a persistent MaterialBanner so the user knows progress
  // may not be saving.  On recovery: banner is hidden automatically.
  Future<void> _saveNow() async {
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
            content: const Text(
                'Saving progress failed — check your connection.'),
            leading: const Icon(Icons.cloud_off_outlined),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _saveFailed = false);
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    }
  }

  // "End" button — saves as in_progress so the user can resume later, then pops.
  Future<void> _endSession() async {
    if (_saving) return;
    setState(() => _saving = true);
    _saveDebounce?.cancel();
    try {
      await ref
          .read(studySessionRepositoryProvider)
          .saveSession(_session, _uid);
    } catch (_) {}
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

    try {
      await ref
          .read(studySessionRepositoryProvider)
          .completeSession(completed, _uid);
    } catch (_) {}

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
    final cardsAsync = ref.watch(cardsInSetProvider(widget.cardSet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardSet.name),
        actions: [
          TextButton(
            // Disable while a save is in flight to prevent double-tap.
            onPressed: _saving ? null : _endSession,
            child: const Text('End'),
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
          Expanded(
            child: cardsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Failed to load cards.')),
              data: (cards) {
                final cardsMap = {for (final c in cards) c.id: c};
                final flashCard = cardsMap[_currentCardId];
                final workbookCard = _workbookCardsMap[_currentCardId];

                // Current card is a workbook card that's still loading.
                if (flashCard == null &&
                    workbookCard == null &&
                    !_workbookCardsLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Route to the workbook view if this card is a workbook card.
                if (workbookCard != null) {
                  return _buildWorkbookView(workbookCard);
                }

                if (flashCard == null) {
                  return const Center(child: Text('Card not found.'));
                }

                // Flash card view — existing two-phase reveal.
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      // Incoming content rises in from slightly below.
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  // _WordCard keeps the same key whether or not translation
                  // is visible, so AnimatedSwitcher only fires for the
                  // fully-revealed transition (the desired slide-in effect).
                  child: _fullyRevealed
                      ? SingleChildScrollView(
                          key: ValueKey('$_currentIndex-revealed'),
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Column(
                            children: [
                              _PrimaryFieldCard(card: flashCard),
                              for (final field in flashCard.fields)
                                _buildField(field),
                              const SizedBox(height: 16),
                            ],
                          ),
                        )
                      : _WordCard(
                          key: ValueKey('$_currentIndex-word'),
                          card: flashCard,
                          onMore: () =>
                              setState(() => _fullyRevealed = true),
                          onNext: _next,
                        ),
                );
              },
            ),
          ),

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
            // Know/Don't Know only enabled in the fully-revealed phase.
            canMark: _fullyRevealed,
          ),
        ],
      ),
    );
  }

  // Persists a success/fail outcome for an interactive field — fire-and-forget.
  void _recordFieldResult(CardField field, bool correct) {
    ref.read(questionResultRepositoryProvider).recordResult(
      userId: _uid,
      cardId: _currentCardId,
      fieldId: field.fieldId,
      fieldName: field.name,
      fieldType: field.type,
      outcome: correct ? AppConstants.resultSuccess : AppConstants.resultFail,
    ).ignore();
  }

  // Dispatch each field to its typed widget using Dart's sealed class switch.
  // Only text_input and multiple_choice get an onResult callback — reveal
  // fields are passive and have no checkable outcome.
  Widget _buildField(CardField field) => switch (field.content) {
        RevealContent c => _RevealFieldCard(field: field, content: c),
        TextInputContent c => _TextInputFieldCard(
            field: field,
            content: c,
            onResult: (correct) => _recordFieldResult(field, correct),
          ),
        MultipleChoiceContent c => _MultipleChoiceFieldCard(
            field: field,
            content: c,
            onResult: (correct) => _recordFieldResult(field, correct),
          ),
      };

  // Persists a success/fail outcome for a workbook question — fire-and-forget.
  // Uses '{cardId}_{questionId}' as the unique field key.
  void _recordWorkbookQuestionResult(WorkbookQuestion question, bool correct) {
    ref.read(questionResultRepositoryProvider).recordResult(
      userId: _uid,
      cardId: _currentCardId,
      fieldId: '${_currentCardId}_${question.questionId}',
      fieldName: question.prompt ?? 'Question',
      fieldType: switch (question) {
        TextInputQuestion _ => AppConstants.fieldTypeTextInput,
        MultipleChoiceQuestion _ => AppConstants.fieldTypeMultipleChoice,
        WordOrderQuestion _ => AppConstants.questionTypeWordOrder,
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
                    _buildWorkbookQuestion(q),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : _WorkbookPromptCard(
              key: ValueKey('$_currentIndex-wb-prompt'),
              card: card,
              onMore: () => setState(() => _fullyRevealed = true),
              onNext: _next,
            ),
    );
  }

  // Dispatch each workbook question to its typed study widget.
  Widget _buildWorkbookQuestion(WorkbookQuestion q) => switch (q) {
        TextInputQuestion q => _WorkbookTextInputCard(
            question: q,
            onResult: (correct) =>
                _recordWorkbookQuestionResult(q, correct),
          ),
        MultipleChoiceQuestion q => _WorkbookMultipleChoiceCard(
            question: q,
            onResult: (correct) =>
                _recordWorkbookQuestionResult(q, correct),
          ),
        WordOrderQuestion q => _WordOrderCard(
            question: q,
            onResult: (correct) =>
                _recordWorkbookQuestionResult(q, correct),
          ),
      };
}

// ---------------------------------------------------------------------------
// _WordCard — handles both the pre-reveal (word only) and translation-revealed
// (word + translation + MORE/NEXT) states internally, so the primary word
// never moves.  AnimatedCrossFade fades the hint out and the translation in
// below the word — no widget swap, no AnimatedSwitcher flash.
// onMore  → parent triggers full slide-in reveal (additional fields).
// onNext  → parent advances to the next card, leaving this card unmarked.
// ---------------------------------------------------------------------------
class _WordCard extends StatefulWidget {
  final FlashCard card;
  final VoidCallback onMore;
  final VoidCallback onNext;
  const _WordCard(
      {super.key, required this.card, required this.onMore, required this.onNext});

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
    // For image cards the cue word is always shown (the image provides context);
    // primaryWordHidden only applies to text-only cards.
    _wordVisible = _isImageCard || !widget.card.primaryWordHidden;
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
            onTapHint: (!_wordVisible || _translationVisible)
                ? null
                : _isImageCard ? 'reveal foreign word' : 'reveal translation',
            child: InkWell(
            onTap: (_wordVisible && !_translationVisible)
                ? () => setState(() => _translationVisible = true)
                : null,
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
                      label: const Text('Show Word'),
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
                              'Tap to reveal',
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
                          // NEXT skips ahead unmarked; MORE enters full reveal.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: widget.onNext,
                                child: const Text('Next'),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                onPressed: widget.onMore,
                                child: const Text('More'),
                              ),
                            ],
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

// ---------------------------------------------------------------------------
// _RevealFieldCard — shows a field label and hides the answer behind a tap.
// ---------------------------------------------------------------------------
class _RevealFieldCard extends StatefulWidget {
  final CardField field;
  final RevealContent content;
  const _RevealFieldCard({required this.field, required this.content});

  @override
  State<_RevealFieldCard> createState() => _RevealFieldCardState();
}

class _RevealFieldCardState extends State<_RevealFieldCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _revealed ? null : () => setState(() => _revealed = true),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(name: widget.field.name),
              const SizedBox(height: 8),
              // Both states are always laid out so the card height is
              // determined by the answer text before the tap, eliminating
              // the height jump on reveal.  Only one state is painted at
              // a time via maintainSize visibility toggling.
              Stack(
                children: [
                  Visibility(
                    visible: _revealed,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      widget.content.answer ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Visibility(
                    visible: !_revealed,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to reveal',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TextInputFieldCard — user types a free-text answer, validated against
// correctAnswers.  Supports case-insensitive (default) or exact matching.
// Shows correct/incorrect feedback and a Try Again button on wrong answers.
// ---------------------------------------------------------------------------
class _TextInputFieldCard extends StatefulWidget {
  final CardField field;
  final TextInputContent content;
  // Called once when the answer is checked — null on cards without tracking.
  final void Function(bool correct)? onResult;
  const _TextInputFieldCard(
      {required this.field, required this.content, this.onResult});

  @override
  State<_TextInputFieldCard> createState() => _TextInputFieldCardState();
}

class _TextInputFieldCardState extends State<_TextInputFieldCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // null = not yet checked; true = correct; false = incorrect
  bool? _result;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final answers = widget.content.correctAnswers ?? [];
    // Always case-insensitive; exactMatch (case-sensitive) to be wired
    // up in a future iteration when the option is added to the UI.
    final correct =
        answers.any((a) => a.toLowerCase() == input.toLowerCase());
    setState(() => _result = correct);
    widget.onResult?.call(correct);
  }

  void _tryAgain() {
    setState(() {
      _controller.clear();
      _result = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answered = _result != null;
    final isCorrect = _result == true;

    // Brightness-aware green so the tint is visible in both light and dark mode.
    final correctGreen = isDark ? Colors.green[300]! : Colors.green[700]!;
    final cardColor = answered
        ? (isCorrect
            ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.08)
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
            _FieldLabel(name: widget.field.name),

            // Optional hint.
            if (widget.content.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.content.hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 12),

            // Text field + Check button (side by side).
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
                    decoration: const InputDecoration(
                      hintText: 'Type your answer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _check,
                    child: const Text('Check'),
                  ),
                ],
              ],
            ),

            // Feedback row — shown after the user submits.
            if (answered) ...[
              const SizedBox(height: 10),
              if (isCorrect)
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      color: correctGreen, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Correct!',
                    style: TextStyle(
                        color: correctGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ])
              else ...[
                Row(
                  children: [
                    Icon(Icons.cancel_outlined,
                        color: scheme.error, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Incorrect',
                        style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                        onPressed: _tryAgain,
                        child: const Text('Try Again')),
                  ],
                ),
                // Show the expected answer after a wrong attempt.
                const SizedBox(height: 4),
                Text(
                  'Answer: ${widget.content.correctAnswers?.join(' / ') ?? ''}',
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
// _MultipleChoiceFieldCard — vertical list of option buttons.
// After selection: correct option turns green, wrong selection turns red.
// ---------------------------------------------------------------------------
class _MultipleChoiceFieldCard extends StatefulWidget {
  final CardField field;
  final MultipleChoiceContent content;
  // Called once when the user selects an option — null on cards without tracking.
  final void Function(bool correct)? onResult;
  const _MultipleChoiceFieldCard(
      {required this.field, required this.content, this.onResult});

  @override
  State<_MultipleChoiceFieldCard> createState() =>
      _MultipleChoiceFieldCardState();
}

class _MultipleChoiceFieldCardState
    extends State<_MultipleChoiceFieldCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = widget.content.options ?? [];
    final correctIndex = widget.content.correctIndex;
    final answered = _selectedIndex != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(name: widget.field.name),
            const SizedBox(height: 12),

            for (var i = 0; i < options.length; i++)
              _OptionButton(
                label: options[i],
                state: _stateFor(i, correctIndex, answered),
                onTap: answered
                    ? null
                    : () {
                        setState(() => _selectedIndex = i);
                        widget.onResult?.call(i == correctIndex);
                      },
              ),

            // Optional explanation shown after answering.
            if (answered && widget.content.explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.content.explanation!,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case _OptionState.correct:
        bg = Colors.green.withValues(alpha: isDark ? 0.22 : 0.12);
        border = isDark ? Colors.green[400]! : Colors.green[700]!;
        fg = isDark ? Colors.green[300]! : Colors.green[800]!;
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
      _OptionState.correct => ', correct',
      _OptionState.incorrect => ', incorrect',
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
  // Marking is disabled until the card has been fully revealed.
  final bool canMark;

  const _NavigationBar({
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.onReview,
    required this.isMarkedSkip,
    required this.isMarkedReview,
    required this.canMark,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == total - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                label: 'Review',
                icon: Icons.flag_outlined,
                activeIcon: Icons.flag,
                isActive: isMarkedReview,
                activeColor: isDark ? Colors.green[300]! : Colors.green[700]!,
                onTap: canMark ? onReview : null,
              ),
              const SizedBox(width: 32),
              _MarkButton(
                label: 'Skip',
                icon: Icons.check_circle_outline,
                activeIcon: Icons.check_circle,
                isActive: isMarkedSkip,
                activeColor: isDark ? Colors.amber[300]! : Colors.amber[700]!,
                onTap: canMark ? onSkip : null,
              ),
            ],
          ),

          // ── Previous / counter / Next ────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 32,
                tooltip: 'Previous card',
                onPressed: currentIndex > 0 ? onPrevious : null,
              ),
              Expanded(
                // Semantic label reads as "Card X of Y" rather than "X / Y".
                child: Semantics(
                  label: 'Card ${currentIndex + 1} of $total',
                  child: ExcludeSemantics(
                    child: Text(
                      '${currentIndex + 1} / $total',
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
                tooltip: isLast ? 'Finish session' : 'Next card',
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
// Shows the prompt text and question count; More enters the questions phase,
// Next advances without engaging (same pattern as _WordCard).
// ---------------------------------------------------------------------------
class _WorkbookPromptCard extends StatelessWidget {
  final WorkbookCard card;
  final VoidCallback onMore;
  final VoidCallback onNext;
  const _WorkbookPromptCard(
      {super.key, required this.card, required this.onMore, required this.onNext});

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
                  '$qCount question${qCount == 1 ? '' : 's'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                        onPressed: onNext, child: const Text('Next')),
                    const SizedBox(width: 16),
                    FilledButton(
                        onPressed: onMore, child: const Text('More')),
                  ],
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
  bool? _result;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final answers = widget.question.correctAnswers;
    final correct = widget.question.exactMatch
        ? answers.any((a) => a == input)
        : answers.any((a) => a.toLowerCase() == input.toLowerCase());
    setState(() => _result = correct);
    widget.onResult?.call(correct);
  }

  void _tryAgain() {
    setState(() {
      _controller.clear();
      _result = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answered = _result != null;
    final isCorrect = _result == true;
    final correctGreen = isDark ? Colors.green[300]! : Colors.green[700]!;
    final cardColor = answered
        ? (isCorrect
            ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.08)
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
                    decoration: const InputDecoration(
                      hintText: 'Type your answer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _check, child: const Text('Check')),
                ],
              ],
            ),
            if (answered) ...[
              const SizedBox(height: 10),
              if (isCorrect)
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      color: correctGreen, size: 20),
                  const SizedBox(width: 6),
                  Text('Correct!',
                      style: TextStyle(
                          color: correctGreen,
                          fontWeight: FontWeight.bold)),
                ])
              else ...[
                Row(children: [
                  Icon(Icons.cancel_outlined,
                      color: scheme.error, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Incorrect',
                        style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                      onPressed: _tryAgain,
                      child: const Text('Try Again')),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Answer: ${widget.question.correctAnswers.join(' / ')}',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = widget.question.options;
    final correctIndex = widget.question.correctIndex;
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
                              setState(() => _selectedIndex = i);
                              widget.onResult?.call(i == correctIndex);
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
                          setState(() => _selectedIndex = i);
                          widget.onResult?.call(i == correctIndex);
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

  _OptionState _stateFor(int i, int correctIndex, bool answered) {
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
    _available = List.from(widget.question.wordBank);
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
    final correct = _ordersEqual(_placed, widget.question.correctOrder);
    setState(() => _result = correct);
    widget.onResult?.call(correct);
  }

  void _tryAgain() {
    setState(() {
      _available = List.from(widget.question.wordBank);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answered = _result != null;
    final isCorrect = _result == true;
    final correctGreen = isDark ? Colors.green[300]! : Colors.green[700]!;
    final prompt = widget.question.prompt;

    final cardColor = answered
        ? (isCorrect
            ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.08)
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
            Text('Your answer:',
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
                      'Tap words below to build your answer',
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
                          tooltip: 'Tap to return',
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),

            // Word bank — available tiles; tap to place.
            Text('Word bank:',
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
                  child: const Text('Check'),
                ),
              )
            else if (isCorrect)
              Row(children: [
                Icon(Icons.check_circle_outline,
                    color: correctGreen, size: 20),
                const SizedBox(width: 6),
                Text('Correct!',
                    style: TextStyle(
                        color: correctGreen,
                        fontWeight: FontWeight.bold)),
              ])
            else ...[
              Row(children: [
                Icon(Icons.cancel_outlined,
                    color: scheme.error, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Incorrect',
                      style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                    onPressed: _tryAgain,
                    child: const Text('Try Again')),
              ]),
              const SizedBox(height: 4),
              Text(
                'Answer: ${widget.question.correctOrder.join(' ')}',
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
