part of '../study_session_screen.dart';

// ---------------------------------------------------------------------------
// _WorkbookMultipleChoiceCard — MC question with list or chips display mode.
// ---------------------------------------------------------------------------
class _WorkbookMultipleChoiceCard extends StatefulWidget {
  final MultipleChoiceQuestion question;
  final void Function(bool correct)? onResult;
  // Resolved display label ("Question N") from the parent; falls back to the
  // question's own prompt when null.
  final String? labelOverride;
  const _WorkbookMultipleChoiceCard(
      {required this.question, this.onResult, this.labelOverride});

  @override
  State<_WorkbookMultipleChoiceCard> createState() =>
      _WorkbookMultipleChoiceCardState();
}

class _WorkbookMultipleChoiceCardState
    extends State<_WorkbookMultipleChoiceCard> {
  int? _selectedIndex;
  late final List<String> _displayOptions;
  late final int? _displayCorrectIndex;
  // First option's FocusNode (#87 follow-up) — a focused OutlinedButton
  // already activates on Enter/Space via Flutter's default button shortcuts,
  // so once this has focus, Enter selects the option instead of falling
  // through to the study screen's reveal/advance shortcut.
  final _firstOptionFocus = FocusNode();

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
    // Auto-focus the first option the moment this question is revealed —
    // this widget is only ever built once per reveal (see _QuestionReveal),
    // so initState firing exactly once here can't re-steal focus on an
    // unrelated rebuild.
    if (_displayOptions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _firstOptionFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _firstOptionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = _displayOptions;
    final correctIndex = _displayCorrectIndex;
    final answered = _selectedIndex != null;
    final prompt = widget.labelOverride ?? widget.question.prompt;

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
                      focusNode: i == 0 ? _firstOptionFocus : null,
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
                  focusNode: i == 0 ? _firstOptionFocus : null,
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