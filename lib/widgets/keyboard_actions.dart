import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// KeyboardActions — adds Enter-to-confirm / Esc-to-cancel to a dialog or
// full-screen editor subtree (#235). Wrap a dialog's or editor's content in it.
//
// - [onConfirm] fires on Enter / NumpadEnter. It's deliberately skipped while
//   a *multi-line* text field has focus (there Enter means "newline") or while
//   a button has focus (there Enter should activate that button). Single-line
//   fields that want in-field Enter-to-submit should still wire their own
//   onSubmitted/onFieldSubmitted — this handler only covers Enter when focus
//   isn't sitting in such a field (e.g. it's on the wrapper itself).
// - [onCancel] fires on Escape. Pass it for editors (routes don't handle Esc)
//   and for barrierDismissible:false dialogs. Do NOT pass it for ordinary
//   barrierDismissible dialogs — Flutter already dismisses those on Esc, so a
//   second handler would pop twice.
// - [autofocus] lets the wrapper claim focus so its shortcuts work before the
//   user touches anything. Set false when a descendant field should keep the
//   initial focus (e.g. a single-field entry dialog).
// ---------------------------------------------------------------------------
class KeyboardActions extends StatelessWidget {
  final Widget child;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool autofocus;

  const KeyboardActions({
    super.key,
    required this.child,
    this.onConfirm,
    this.onCancel,
    this.autofocus = true,
  });

  // True when Enter belongs to whatever currently has focus (a focused button,
  // or a multi-line text field) rather than to our confirm action.
  bool _enterBelongsToFocusedWidget() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    // A focused button already activates on Enter via Flutter's defaults.
    if (ctx.findAncestorWidgetOfExactType<TextButton>() != null ||
        ctx.findAncestorWidgetOfExactType<FilledButton>() != null ||
        ctx.findAncestorWidgetOfExactType<OutlinedButton>() != null ||
        ctx.findAncestorWidgetOfExactType<ElevatedButton>() != null) {
      return true;
    }
    // A focused multi-line field treats Enter as a newline. (maxLines == 1 for
    // single-line fields — those should submit, so they don't count here.)
    final editable = ctx.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && editable.maxLines != 1;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape && onCancel != null) {
      onCancel!();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (onConfirm == null) return KeyEventResult.ignored;
      // Let a focused button / multi-line field keep Enter for itself.
      if (_enterBelongsToFocusedWidget()) return KeyEventResult.ignored;
      onConfirm!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: autofocus, onKeyEvent: _onKey, child: child);
  }
}
