part of '../study_session_screen.dart';

// ===========================================================================
// Shared helpers for the workbook question-card widgets.
//
// These live in the same library as study_session_screen.dart (via `part of`)
// so the underscore-private helpers below stay visible to every question card
// without exposing a public API surface. Each question type lives in its own
// part file beside this one.
// ===========================================================================

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

// ---------------------------------------------------------------------------
// _OptionButton / _OptionState — a multiple-choice option button with semantic
// colour coding once the question has been answered.
// ---------------------------------------------------------------------------
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
// _answeredCardColor — the shared result tint applied to a question Card once
// answered: green for accepted, a soft red for incorrect, transparent before.
// ---------------------------------------------------------------------------
Color? _answeredCardColor(BuildContext context,
    {required bool answered, required bool accepted}) {
  if (!answered) return null;
  final scheme = Theme.of(context).colorScheme;
  return accepted
      ? context.appColors.correctSurface
      : scheme.errorContainer.withValues(alpha: 0.4);
}

// ---------------------------------------------------------------------------
// _measuredInputWidth — sizes a fill-in-the-blanks / grid text-input box to fit
// its expected answer (#216). Lays out [answer] at [style] with a TextPainter
// (honouring the ambient text scale), then adds the field's horizontal content
// padding plus slack for the cursor and border. The result is clamped to
// [minWidth, maxWidth] so single-character answers stay tappable and long ones
// don't overflow their row — callers pass an available-width-derived maxWidth.
//
// The length hint is intentional (#216): box width loosely signals answer
// length, like a printed fill-in exercise.
// ---------------------------------------------------------------------------
double _measuredInputWidth(
  BuildContext context,
  String answer,
  TextStyle? style, {
  double contentPadding = 8, // horizontal contentPadding per side of the field
  double minWidth = 52,
  double maxWidth = 220,
}) {
  final painter = TextPainter(
    text: TextSpan(text: answer, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  // Measured glyphs + padding on both sides + slack for the cursor / border.
  final width = painter.width + contentPadding * 2 + 14;
  return width.clamp(minWidth, maxWidth.clamp(minWidth, double.infinity));
}

// ---------------------------------------------------------------------------
// _ResultBanner — the post-answer feedback row shared by every question type.
//
// [accepted] picks the icon and colour (check / green vs cancel / red).
// [message] is the headline (a FeedbackPhrases string or a fixed label).
// [detail] is an optional line rendered below the row (e.g. the correct-form
// hint or the answer reveal).
//
// The label is always Expanded so longer feedback phrases wrap rather than
// overflow the row.
// ---------------------------------------------------------------------------
class _ResultBanner extends StatelessWidget {
  final bool accepted;
  final String message;
  final Widget? detail;
  const _ResultBanner({
    required this.accepted,
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accepted ? context.appColors.onCorrectSurface : scheme.error;
    final icon = accepted ? Icons.check_circle_outline : Icons.cancel_outlined;

    final row = Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    ]);

    if (detail == null) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [row, const SizedBox(height: 4), detail!],
    );
  }
}

// ---------------------------------------------------------------------------
// _WordBankChips — the tappable word pool shared by fill-in-the-blanks and the
// grid card (pill completion mode). Pool entries already placed (their index in
// [usedIds]) are hidden; tapping a remaining chip calls [onTap] with its index.
// ---------------------------------------------------------------------------
class _WordBankChips extends StatelessWidget {
  final List<String> pool;
  final Set<int> usedIds;
  final void Function(int poolId) onTap;
  const _WordBankChips(
      {required this.pool, required this.usedIds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            for (var p = 0; p < pool.length; p++)
              if (!usedIds.contains(p))
                ActionChip(
                  label: Text(pool[p]),
                  onPressed: () => onTap(p),
                  visualDensity: VisualDensity.compact,
                ),
          ],
        ),
      ],
    );
  }
}