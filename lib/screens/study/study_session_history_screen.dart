import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/study_session_provider.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// StudySessionHistoryScreen — list of all past sessions for a single set.
//
// Streamed live via sessionHistoryProvider (newest first).  Read-only;
// resuming an in-progress session is handled by StudySetupScreen.
// ---------------------------------------------------------------------------
class StudySessionHistoryScreen extends ConsumerWidget {
  final CardSet cardSet;
  const StudySessionHistoryScreen({super.key, required this.cardSet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider(cardSet.id));

    return Scaffold(
      appBar: AppBar(title: Text('${cardSet.name} — History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Failed to load history.')),
        data: (sessions) => sessions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No sessions yet.\nStart studying to build your history.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: sessions.length,
                itemBuilder: (ctx, i) =>
                    _SessionHistoryTile(session: sessions[i]),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One row in the history list.
// Shows: date, status chip, cards studied / total, known count, duration.
// ---------------------------------------------------------------------------
class _SessionHistoryTile extends StatelessWidget {
  final StudySession session;
  const _SessionHistoryTile({required this.session});

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompleted =
        session.status == AppConstants.sessionStatusCompleted;
    final studied = session.totalCardsStudied;
    final total = session.cardSequence.length;
    final duration = _formatDuration(session.sessionStats.totalTimeSpent);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + status chip.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(session.startTime),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(isCompleted ? 'Completed' : 'In Progress'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isCompleted
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.green[300]
                            : Colors.green[800])
                        : scheme.onSurfaceVariant,
                  ),
                  backgroundColor: isCompleted
                      ? Colors.green.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.25
                              : 0.15)
                      : scheme.surfaceContainerHighest,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Stats: cards · time
            Row(
              children: [
                Icon(Icons.style_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('$studied / $total cards',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(duration,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
