import 'package:flutter/material.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/screens/study/study_setup_screen.dart';

// ---------------------------------------------------------------------------
// StudySessionSummaryScreen — shown immediately after session completion.
//
// Displays stats from the completed session (cards studied, known %, time).
// "Study Again" replaces this screen with a fresh StudySetupScreen.
// "Done" pops back to SetDetailScreen.
// ---------------------------------------------------------------------------
class StudySessionSummaryScreen extends StatelessWidget {
  final StudySession session;
  final CardSet cardSet;

  const StudySessionSummaryScreen({
    super.key,
    required this.session,
    required this.cardSet,
  });

  // Format milliseconds as "Xm Ys" or just "Ys" for short sessions.
  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final studied = session.totalCardsStudied;
    final known = session.cardsKnown;
    final unknown = session.cardsUnknown;
    final knownPct = studied > 0 ? (known / studied * 100).round() : 0;
    final duration = _formatDuration(session.sessionStats.totalTimeSpent);

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
              cardSet.name,
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
                      value: '$unknown',
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
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => StudySetupScreen(cardSet: cardSet),
                ),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('Study Again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
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
