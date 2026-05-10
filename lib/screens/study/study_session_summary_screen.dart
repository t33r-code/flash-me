import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/screens/study/study_session_screen.dart';
import 'package:flash_me/utils/constants.dart';

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
    extends ConsumerState<StudySessionSummaryScreen> {
  bool _starting = false;

  String get _uid => ref.read(authStateProvider).asData?.value ?? '';

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

      final progress = {for (final id in sequence) id: const CardSessionData()};
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
                ),
                _uid,
              );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StudySessionScreen(
              session: newSession,
              cardSet: widget.cardSet,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to start session. Please try again.')),
        );
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final studied = widget.session.totalCardsStudied;
    final known = widget.session.cardsKnown;
    final unknown = widget.session.cardsUnknown;
    final knownPct = studied > 0 ? (known / studied * 100).round() : 0;
    final unknownPct = studied > 0 ? (unknown / studied * 100).round() : 0;
    final duration =
        _formatDuration(widget.session.sessionStats.totalTimeSpent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        // No back arrow — the session is done; use the buttons below to navigate.
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero area ────────────────────────────────────────────────
            Icon(Icons.check_circle_outline, size: 80, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              widget.cardSet.name,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ── Stats card ───────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _StatRow(
                      icon: Icons.style_outlined,
                      label: 'Cards studied',
                      value: '$studied',
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      icon: Icons.thumb_up_outlined,
                      iconColor: Colors.green[700],
                      label: 'Known',
                      value: '$known  ($knownPct%)',
                    ),
                    const SizedBox(height: 8),
                    _StatRow(
                      icon: Icons.thumb_down_outlined,
                      iconColor: scheme.error,
                      label: "Don't Know",
                      value: '$unknown  ($unknownPct%)',
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      icon: Icons.timer_outlined,
                      label: 'Time',
                      value: duration,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Actions ──────────────────────────────────────────────────
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
              label: const Text('Study Again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _starting ? null : () => Navigator.of(context).pop(),
              child: const Text('Done'),
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
