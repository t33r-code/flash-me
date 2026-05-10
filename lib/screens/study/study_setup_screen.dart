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
// StudySetupScreen — entry point for studying a set.
//
// On open it checks for a resumable in-progress session.  If one exists the
// user can either Resume it or discard it and start fresh.  Either way the
// shuffle toggle lets them randomise the card order for new sessions.
// ---------------------------------------------------------------------------
class StudySetupScreen extends ConsumerStatefulWidget {
  final CardSet cardSet;
  const StudySetupScreen({super.key, required this.cardSet});

  @override
  ConsumerState<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends ConsumerState<StudySetupScreen> {
  bool _shuffle = false;
  // true while the initial getActiveSession() call is in flight
  bool _checkingSession = true;
  bool _starting = false;
  StudySession? _activeSession;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
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
  Future<void> _startNew(List<String> cardIds) async {
    setState(() => _starting = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';

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

      // Blank per-card progress for every card in the sequence.
      final progress = {for (final id in sequence) id: const CardSessionData()};

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
            ),
            uid,
          );

      if (mounted) {
        // pushReplacement so back from the session screen returns to SetDetailScreen.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              StudySessionScreen(session: session, cardSet: widget.cardSet),
        ));
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

  // Resumes the existing in-progress session without any setup work.
  void _resume() {
    final session = _activeSession;
    if (session == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          StudySessionScreen(session: session, cardSet: widget.cardSet),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Card IDs are already streamed by SetDetailScreen's provider; reading
    // them here keeps the count in sync without a second Firestore request.
    final cardIds =
        ref.watch(cardIdsInSetProvider(widget.cardSet.id)).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: _checkingSession
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                            '${cardIds.length} card${cardIds.length == 1 ? '' : 's'}',
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
                  Text('Options',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  // ── Shuffle toggle ─────────────────────────────────────
                  Card(
                    child: SwitchListTile(
                      title: const Text('Shuffle cards'),
                      subtitle:
                          const Text('Randomise card order for this session'),
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
                          : () => _startNew(cardIds),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Start New Session'),
                    ),
                  ] else
                    // No active session — primary start button only.
                    FilledButton.icon(
                      onPressed: _starting || cardIds.isEmpty
                          ? null
                          : () => _startNew(cardIds),
                      icon: _starting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('Start Session'),
                    ),

                  // Hint if the set has no cards.
                  if (cardIds.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Add cards to this set before studying.',
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
                'Session in progress',
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
              '$done of $total cards reviewed',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}
