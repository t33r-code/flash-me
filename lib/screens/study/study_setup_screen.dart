import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_candidate.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_mark_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/language_provider.dart';
import 'package:flash_me/providers/study_filter_provider.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/screens/study/study_session_history_screen.dart';
import 'package:flash_me/screens/study/study_session_screen.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/languages.dart';
import 'package:flash_me/utils/study_filters.dart';
import 'package:flash_me/utils/transitions.dart';


// ---------------------------------------------------------------------------
// StudySetupScreen — entry point for studying a set.
//
// On open it checks for a resumable in-progress session.  If one exists the
// user can either Resume it or discard it and start fresh.  Either way the
// shuffle toggle lets them randomise the card order for new sessions.
// ---------------------------------------------------------------------------
class StudySetupScreen extends ConsumerStatefulWidget {
  final CardSet cardSet;
  // When non-null, this is a synthetic filtered-study set (Review / Mistakes):
  // the pool is resolved from study signals, there is no resumable session, and
  // the session is stored under the mode's sentinel set ID.
  final StudyMode? syntheticMode;
  const StudySetupScreen(
      {super.key, required this.cardSet, this.syntheticMode});

  bool get isSynthetic => syntheticMode != null;

  @override
  ConsumerState<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends ConsumerState<StudySetupScreen> {
  bool _shuffle = false;
  // true while the initial getActiveSession() call is in flight
  bool _checkingSession = true;
  bool _starting = false;
  StudySession? _activeSession;
  // Selected language-filter key for synthetic sets (null = not yet chosen, so
  // the computed default applies). One of: langFilterAll, langFilterUnspecified,
  // or an ISO 639-1 code.
  String? _selectedLangKey;

  @override
  void initState() {
    super.initState();
    if (widget.isSynthetic) {
      // Synthetic sets are not resumable — skip the active-session lookup.
      _checkingSession = false;
    } else {
      _checkActiveSession();
    }
  }

  Future<void> _checkActiveSession() async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      final session = await ref
          .read(studySessionRepositoryProvider)
          .getActiveSession(widget.cardSet.id, uid);
      if (mounted) {
        setState(() {
          _activeSession = session;
          _checkingSession = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingSession = false);
    }
  }

  // Builds a new card sequence, writes the session to Firestore, then
  // navigates into the session screen (replacing this screen in the stack).
  Future<void> _startNew(List<String> cardIds,
      {Map<String, String> cardTypeMap = const {}}) async {
    setState(() => _starting = true);
    final l10n = context.l10n;
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';

      // Real sets derive the cardId→type map from their setCards join docs;
      // synthetic sets pass it in (built from the resolved candidates). The map
      // lets the study session dispatch flash vs workbook cards.
      if (!widget.isSynthetic) {
        final setCards = await ref
            .read(cardSetRepositoryProvider)
            .watchSetCards(widget.cardSet.id, uid)
            .first;
        cardTypeMap = {for (final sc in setCards) sc.cardId: sc.cardType};
      }

      // Build card order — optionally shuffled via Fisher-Yates.
      final sequence = List<String>.from(cardIds);
      if (_shuffle) {
        final rng = Random();
        for (var i = sequence.length - 1; i > 0; i--) {
          final j = rng.nextInt(i + 1);
          final tmp = sequence[i];
          sequence[i] = sequence[j];
          sequence[j] = tmp;
        }
      }

      // Load persistent marks so Skip/Review state carries over from previous sessions.
      final marks = await ref.read(cardMarkRepositoryProvider).watchMarks(uid).first;
      final marksMap = {for (final m in marks) m.cardId: m.mark};

      // Per-card progress — pre-populated with any existing marks.
      final progress = {
        for (final id in sequence)
          id: CardSessionData(
            markedKnown: marksMap[id] == AppConstants.markSkip,
            markedUnknown: marksMap[id] == AppConstants.markReview,
          ),
      };

      final now = DateTime.now();
      final session = await ref.read(studySessionRepositoryProvider).createSession(
            StudySession(
              id: '',
              setId: widget.cardSet.id,
              startTime: now,
              lastAccessTime: now,
              status: AppConstants.sessionStatusInProgress,
              cardProgress: progress,
              cardSequence: sequence,
              currentCardIndex: 0,
              totalCardsStudied: 0,
              cardsKnown: 0,
              cardsUnknown: 0,
              sessionStats: const SessionStats(),
              shuffled: _shuffle,
              cardTypeMap: cardTypeMap,
            ),
            uid,
          );

      if (mounted) {
        // pushReplacement so back from the session screen returns to SetDetailScreen.
        Navigator.of(context).pushReplacement(
          studyEnterRoute(StudySessionScreen(session: session, cardSet: widget.cardSet)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorFailedStartSession)),
        );
        setState(() => _starting = false);
      }
    }
  }

  // Resumes the existing in-progress session without any setup work.
  void _resume() {
    final session = _activeSession;
    if (session == null) return;
    Navigator.of(context).pushReplacement(
      studyEnterRoute(StudySessionScreen(session: session, cardSet: widget.cardSet)),
    );
  }

  // Dropdown to filter the synthetic pool by target language. Options: "All
  // languages", each present language (by count desc, then name) with its count,
  // and "Unspecified" for language-less cards (only if any exist).
  Widget _buildLanguageFilterCard(
      BuildContext context, Map<String?, int> counts, String selection) {
    final langEntries = counts.entries.where((e) => e.key != null).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : (languageName(a.key) ?? a.key!)
                .compareTo(languageName(b.key) ?? b.key!);
      });

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
          value: langFilterAll, child: Text(context.l10n.labelAllLanguages)),
      for (final e in langEntries)
        DropdownMenuItem(
          value: e.key,
          child: Text('${languageName(e.key) ?? e.key} (${e.value})'),
        ),
      if (counts.containsKey(null))
        DropdownMenuItem(
          value: langFilterUnspecified,
          child: Text(
              '${context.l10n.labelLanguageUnspecified} (${counts[null]})'),
        ),
    ];

    return Card(
      child: ListTile(
        title: Text(context.l10n.labelStudyLanguage),
        trailing: DropdownButton<String>(
          value: selection,
          underline: const SizedBox.shrink(),
          // Suppress the grey focus highlight that otherwise boxes the selected
          // value after a choice is made, so it sits flush in the bar.
          focusColor: Colors.transparent,
          onChanged: _starting
              ? null
              : (v) {
                  if (v != null) setState(() => _selectedLangKey = v);
                },
          items: items,
        ),
      ),
    );
  }

  // The empty-pool hint — specific to the synthetic mode, generic otherwise.
  String _emptyPoolMessage(BuildContext context) {
    final l10n = context.l10n;
    if (!widget.isSynthetic) return l10n.messageAddCardsBeforeStudying;
    return widget.syntheticMode == StudyMode.review
        ? l10n.messageNoReviewCards
        : l10n.messageNoMistakeCards;
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the card pool. Real sets stream their membership; synthetic
    // filtered modes resolve candidates from the user's study signals and apply
    // the language filter.
    final List<String> cardIds;
    Map<String, String> syntheticTypeMap = const {};
    bool poolLoading = false;
    bool showLanguageFilter = false;
    String langSelection = langFilterAll;
    Map<String?, int> langCounts = const {};

    if (widget.isSynthetic) {
      final candidatesAsync =
          ref.watch(studyCandidatesProvider(widget.syntheticMode!));
      poolLoading = candidatesAsync.isLoading;
      final candidates =
          candidatesAsync.asData?.value ?? const <StudyCandidate>[];

      // Show a language selector only when the pool spans more than one
      // language bucket; default to last-used / most-common (see study_filters).
      showLanguageFilter = shouldShowLanguageFilter(candidates);
      if (showLanguageFilter) {
        langCounts = targetLanguageCounts(candidates);
        final lastTarget = ref.watch(lastUsedLanguagesProvider)?.target;
        langSelection = _selectedLangKey ??
            defaultLanguageSelection(candidates, lastTarget);
      }

      final filtered = showLanguageFilter
          ? applyStudyFilters(candidates,
              [(c) => candidateMatchesLanguage(c, langSelection)])
          : candidates;

      cardIds = [for (final c in filtered) c.cardId];
      syntheticTypeMap = {for (final c in filtered) c.cardId: c.cardType};
    } else {
      // Already streamed by SetDetailScreen's provider; reading here keeps the
      // count in sync without a second Firestore request.
      cardIds = ref
              .watch(cardIdsInSetProvider(widget.cardSet.id))
              .asData
              ?.value ??
          [];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titleStudy),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: context.l10n.tooltipSessionHistory,
            onPressed: () => Navigator.of(context).push(
              studyEnterRoute(StudySessionHistoryScreen(cardSet: widget.cardSet)),
            ),
          ),
        ],
      ),
      body: _checkingSession || poolLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Set info card ──────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.cardSet.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.labelCardCount(cardIds.length),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(context.l10n.titleOptions,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  // ── Language filter (synthetic, multi-language only) ────
                  if (showLanguageFilter) ...[
                    _buildLanguageFilterCard(context, langCounts, langSelection),
                    const SizedBox(height: 8),
                  ],

                  // ── Shuffle toggle ─────────────────────────────────────
                  Card(
                    child: SwitchListTile(
                      title: Text(context.l10n.labelShuffleCards),
                      subtitle:
                          Text(context.l10n.messageShuffleCardsSubtitle),
                      value: _shuffle,
                      // Disable while a start is in progress.
                      onChanged:
                          _starting ? null : (v) => setState(() => _shuffle = v),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Action buttons ─────────────────────────────────────
                  if (_activeSession != null) ...[
                    // Show resume card + a secondary "start new" option.
                    _ResumeCard(session: _activeSession!, onResume: _resume),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _starting || cardIds.isEmpty
                          ? null
                          : () => _startNew(cardIds,
                              cardTypeMap: syntheticTypeMap),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.actionStartNewSession),
                    ),
                  ] else
                    // No active session — primary start button only.
                    FilledButton.icon(
                      onPressed: _starting || cardIds.isEmpty
                          ? null
                          : () => _startNew(cardIds,
                              cardTypeMap: syntheticTypeMap),
                      icon: _starting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(context.l10n.actionStartSession),
                    ),

                  // Hint when the pool is empty — mode-specific for synthetic
                  // sets, generic for real sets.
                  if (cardIds.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _emptyPoolMessage(context),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shows an in-progress session with a progress bar and Resume button.
// ---------------------------------------------------------------------------
class _ResumeCard extends StatelessWidget {
  final StudySession session;
  final VoidCallback onResume;
  const _ResumeCard({required this.session, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = session.currentCardIndex;
    final total = session.cardSequence.length;
    final progress = total > 0 ? done / total : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.history, color: scheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                l10n.labelSessionInProgress,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: scheme.onSecondaryContainer.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.messageCardsReviewed(done, total),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.actionResume),
            ),
          ],
        ),
      ),
    );
  }
}
