part of '../study_session_screen.dart';

// ---------------------------------------------------------------------------
// _WordOrderCard — word order question.
// Available tiles sit in the bank row; tap to place in the answer row.
// Tap a placed tile to return it to the bank.  Check validates the order.
// ---------------------------------------------------------------------------
class _WordOrderCard extends StatefulWidget {
  final WordOrderQuestion question;
  final void Function(bool correct)? onResult;
  const _WordOrderCard({required this.question, this.onResult});

  @override
  State<_WordOrderCard> createState() => _WordOrderCardState();
}

class _WordOrderCardState extends State<_WordOrderCard> {
  late List<String> _available;
  final List<String> _placed = [];
  bool? _result;

  @override
  void initState() {
    super.initState();
    _available = List.from(widget.question.wordBank ?? []);
  }

  void _placeTile(int index) {
    if (_result != null) return;
    setState(() => _placed.add(_available.removeAt(index)));
  }

  void _returnTile(int index) {
    if (_result != null) return;
    setState(() => _available.add(_placed.removeAt(index)));
  }

  void _check() {
    final correct = _ordersEqual(_placed, widget.question.correctOrder ?? []);
    setState(() => _result = correct);
    correct ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(correct);
  }

  void _tryAgain() {
    setState(() {
      _available = List.from(widget.question.wordBank ?? []);
      _placed.clear();
      _result = null;
    });
  }

  bool _ordersEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = _result != null;
    final isCorrect = _result == true;
    final prompt = widget.question.prompt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _answeredCardColor(context,
          answered: answered, accepted: isCorrect),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // Answer row — placed tiles; tap to return to bank.
            Text(context.l10n.labelYourAnswer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _placed.isEmpty
                  ? Text(
                      context.l10n.labelTapWordsToBuild,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _placed.asMap().entries.map((e) {
                        return ActionChip(
                          label: Text(e.value),
                          onPressed:
                              answered ? null : () => _returnTile(e.key),
                          visualDensity: VisualDensity.compact,
                          tooltip: context.l10n.tooltipTapToReturn,
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),

            // Word bank — available tiles; tap to place.
            Text(context.l10n.labelWordBank,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _available.asMap().entries.map((e) {
                return ActionChip(
                  label: Text(e.value),
                  onPressed: answered ? null : () => _placeTile(e.key),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Check / feedback row.
            if (!answered)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed:
                      _placed.isEmpty ? null : _check,
                  child: Text(context.l10n.actionCheck),
                ),
              )
            else if (isCorrect)
              _ResultBanner(
                accepted: true,
                message: context.l10n.labelCorrect,
              )
            else
              _ResultBanner(
                accepted: false,
                message: context.l10n.labelIncorrect,
                trailing: TextButton(
                    onPressed: _tryAgain,
                    child: Text(context.l10n.actionTryAgain)),
                detail: Text(
                  context.l10n.messageAnswerReveal(
                      (widget.question.correctOrder ?? []).join(' ')),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}