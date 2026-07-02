part of '../study_session_screen.dart';

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
  AnswerResult? _result;
  // Canonical form of the first accepted answer (for "correct form" hint).
  String? _matchedAnswer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final answers = widget.question.correctAnswers ?? [];
    // Scan accepted answers — prefer an exact normalised match over a close one.
    AnswerResult best = AnswerResult.incorrect;
    String? matched;
    for (final a in answers) {
      final r = AppHelpers.checkAnswer(input, [a],
          exact: widget.question.exactMatch);
      if (r == AnswerResult.correct) { best = r; matched = a; break; }
      if (r == AnswerResult.close && best == AnswerResult.incorrect) {
        best = r; matched = a;
      }
    }
    setState(() { _result = best; _matchedAnswer = matched; });
    best != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(best != AnswerResult.incorrect);
  }

  void _tryAgain() {
    setState(() {
      _controller.clear();
      _result = null;
      _matchedAnswer = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final prompt = widget.question.prompt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _answeredCardColor(context,
          answered: answered, accepted: isAccepted),
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
                    decoration: InputDecoration(
                      hintText: context.l10n.hintTypeYourAnswer,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _check, child: Text(context.l10n.actionCheck)),
                ],
              ],
            ),
            if (answered) ...[
              const SizedBox(height: 10),
              if (isAccepted)
                _ResultBanner(
                  accepted: true,
                  message: FeedbackPhrases.forResult(_result!, context.l10n),
                  // Show canonical spelling whenever the user's input differed —
                  // covers both diacritic differences and close (fuzzy) matches.
                  detail: (_matchedAnswer != null &&
                          _matchedAnswer != _controller.text.trim())
                      ? Text(
                          context.l10n.messageCorrectForm(_matchedAnswer!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        )
                      : null,
                )
              else
                _ResultBanner(
                  accepted: false,
                  message: FeedbackPhrases.forResult(_result!, context.l10n),
                  trailing: TextButton(
                      onPressed: _tryAgain,
                      child: Text(context.l10n.actionTryAgain)),
                  detail: Text(
                    context.l10n.messageAnswerReveal(
                        (widget.question.correctAnswers ?? []).join(' / ')),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}