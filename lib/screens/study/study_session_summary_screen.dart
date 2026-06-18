import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_mark_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/screens/study/study_session_screen.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/transitions.dart';
import 'package:flash_me/widgets/offline_banner.dart';

// ---------------------------------------------------------------------------
// StudySessionSummaryScreen — shown immediately after session completion.
//
// Displays stats (cards studied, known %, time).  "Study Again" creates a
// new session directly, re-applying the same shuffle setting as the last one.
// "Done" pops back to SetDetailScreen.
// ---------------------------------------------------------------------------
class StudySessionSummaryScreen extends ConsumerStatefulWidget {
  final StudySession session;
  final CardSet cardSet;

  const StudySessionSummaryScreen({
    super.key,
    required this.session,
    required this.cardSet,
  });

  @override
  ConsumerState<StudySessionSummaryScreen> createState() =>
      _StudySessionSummaryScreenState();
}

class _StudySessionSummaryScreenState
    extends ConsumerState<StudySessionSummaryScreen>
    with SingleTickerProviderStateMixin {
  bool _starting = false;

  late final AnimationController _animController;
  // Three staggered sections: hero icon+title, stats card, action buttons.
  late final Animation<double> _heroAnim;
  late final Animation<double> _statsAnim;
  late final Animation<double> _actionsAnim;

  String get _uid => ref.read(authStateProvider).asData?.value ?? '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _statsAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
    );
    _actionsAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Format milliseconds as "Xm Ys" or just "Ys" for short sessions.
  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  // Creates a new session directly, re-using the shuffle setting from the
  // completed session so the user doesn't need to go back to the setup screen.
  Future<void> _studyAgain() async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      final cardIds =
          ref.read(cardIdsInSetProvider(widget.cardSet.id)).asData?.value ?? [];
      if (cardIds.isEmpty) return;

      // Fetch setCard join docs to rebuild cardTypeMap (flash vs workbook).
      // Without this, workbook cards are not recognised in the new session.
      final setCards = await ref
          .read(cardSetRepositoryProvider)
          .watchSetCards(widget.cardSet.id, _uid)
          .first;
      final cardTypeMap = {for (final sc in setCards) sc.cardId: sc.cardType};

      // Load persistent marks so Skip/Review state carries over into the new session.
      final marks = await ref.read(cardMarkRepositoryProvider).watchMarks(_uid).first;
      final marksMap = {for (final m in marks) m.cardId: m.mark};

      // Always shuffle on Study Again — the user has already seen the cards
      // in their previous order, so variety is the point.
      final sequence = List<String>.from(cardIds);
      final rng = Random();
      for (var i = sequence.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = sequence[i];
        sequence[i] = sequence[j];
        sequence[j] = tmp;
      }

      // Per-card progress — pre-populated with any existing marks.
      final progress = {
        for (final id in sequence)
          id: CardSessionData(
            markedKnown: marksMap[id] == AppConstants.markSkip,
            markedUnknown: marksMap[id] == AppConstants.markReview,
          ),
      };
      final now = DateTime.now();
      final newSession =
          await ref.read(studySessionRepositoryProvider).createSession(
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
                  shuffled: widget.session.shuffled,
                  cardTypeMap: cardTypeMap,
                ),
                _uid,
              );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          studyEnterRoute(StudySessionScreen(
            session: newSession,
            cardSet: widget.cardSet,
          )),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedStartSession)),
        );
        setState(() => _starting = false);
      }
    }
  }

  // Wraps a child in a fade + upward slide driven by [anim].
  Widget _animated(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studied = widget.session.totalCardsStudied;
    final known = widget.session.cardsKnown;
    final unknown = widget.session.cardsUnknown;

    // Flashcard count = total studied minus workbook cards (which have no recall
    // self-evaluation). "Skipped" = flashcards seen but not self-evaluated.
    final workbookCount = widget.session.cardTypeMap.values
        .where((t) => t == AppConstants.cardTypeWorkbook)
        .length;
    final flashcardsStudied = (studied - workbookCount).clamp(0, studied);
    final skipped = (flashcardsStudied - known - unknown).clamp(0, studied);

    final knownPct =
        flashcardsStudied > 0 ? (known / flashcardsStudied * 100).round() : 0;
    final unknownPct =
        flashcardsStudied > 0 ? (unknown / flashcardsStudied * 100).round() : 0;

    final questionsTotal = widget.session.questionsTotal;
    final questionsCorrect = widget.session.questionsCorrect;

    final duration =
        _formatDuration(widget.session.sessionStats.totalTimeSpent);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titleSessionComplete),
        // No back arrow — the session is done; use the buttons below to navigate.
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.actionDone,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OfflineBanner(),
            // ── Hero area ────────────────────────────────────────────────
            _animated(
              _heroAnim,
              Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    widget.cardSet.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Stats card ───────────────────────────────────────────────
            _animated(
              _statsAnim,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _StatRow(
                        icon: Icons.style_outlined,
                        label: context.l10n.labelCardsStudied,
                        value: '$studied',
                      ),
                      const Divider(height: 24),
                      _StatRow(
                        icon: Icons.check,
                        iconColor:
                            isDark ? Colors.green[400] : Colors.green[700],
                        label: context.l10n.labelKnewIt,
                        value: '$known  ($knownPct%)',
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        icon: Icons.close,
                        iconColor: scheme.error,
                        label: context.l10n.labelNotYet,
                        value: '$unknown  ($unknownPct%)',
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        icon: Icons.remove,
                        label: context.l10n.labelSkippedStat,
                        value: '$skipped',
                      ),
                      // Question score — only shown if the session had questions.
                      if (questionsTotal > 0) ...[
                        const Divider(height: 24),
                        _StatRow(
                          icon: Icons.quiz_outlined,
                          label: context.l10n.labelQuestionsStat,
                          value: '$questionsCorrect / $questionsTotal  (${(questionsCorrect / questionsTotal * 100).round()}%)',
                        ),
                      ],
                      const Divider(height: 24),
                      _StatRow(
                        icon: Icons.timer_outlined,
                        label: context.l10n.labelTimeStat,
                        value: duration,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Actions ──────────────────────────────────────────────────
            _animated(
              _actionsAnim,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _starting ? null : _studyAgain,
                    icon: _starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.replay),
                    label: Text(context.l10n.actionStudyAgain),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _starting ? null : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.actionDone),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One row in the stats card: icon + label flush left, value flush right.
class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
