import 'package:flutter/material.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_session.dart';

// ---------------------------------------------------------------------------
// StudySessionScreen — placeholder for Phase 5b.
//
// Receives a fully initialised (or resumed) StudySession and the set being
// studied.  The actual card display, field interaction, navigation controls,
// and persistence are implemented in Phase 5b; this scaffold exists so the
// Phase 5a flow (setup → session) is end-to-end testable.
// ---------------------------------------------------------------------------
class StudySessionScreen extends StatelessWidget {
  final StudySession session;
  final CardSet cardSet;
  const StudySessionScreen(
      {super.key, required this.session, required this.cardSet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cardSet.name),
        actions: [
          // End session — pops back to the set detail screen.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('End'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Study Mode',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Card display coming in Phase 5b',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Show basic session info so the flow can be verified.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                          label: 'Cards',
                          value: '${session.cardSequence.length}'),
                      _InfoRow(
                          label: 'Shuffled',
                          // A shuffled session has a different order than
                          // cardIds sorted by addedAt; we can't tell from
                          // the model alone, so just show the count.
                          value: session.cardSequence.length > 1 ? '—' : 'n/a'),
                      _InfoRow(label: 'Session ID', value: session.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
