// Verifies the mechanism #87's study-session keyboard shortcuts rely on:
// a key event handler on an ancestor Focus node must NOT fire while a
// descendant TextField has focus, otherwise typing a literal letter (e.g. 'k'
// or 'u') into a text-input answer would double as a Skip/Review shortcut.
//
// This doesn't exercise StudySessionScreen itself (it needs a live Firebase
// session + card data to build), just the same guard used there — in an
// isolated harness, since the actual risk being verified is a general
// Flutter focus-bubbling behaviour, not anything specific to the screen's
// private state.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ancestor key handler is skipped while a TextField has focus', (
    tester,
  ) async {
    var handlerFired = 0;
    // A separate node for the "ancestor has focus, nothing text-editing
    // does" case — mirrors the study screen's own Focus(autofocus: true)
    // reclaiming focus once the text field is done with it.
    final ancestorFocus = FocusNode();
    final textFieldFocus = FocusNode();
    final controller = TextEditingController();
    addTearDown(() {
      ancestorFocus.dispose();
      textFieldFocus.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: ancestorFocus,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              // The same guard used in study_session_screen.dart. The
              // focused context's own widget is the `Focus` EditableText
              // wraps itself in (confirmed via a scratch runtimeType print
              // while writing this test), not EditableText itself — hence
              // the ancestor walk rather than a plain `is` check.
              final isTextField =
                  FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<EditableText>() !=
                  null;
              if (isTextField) return KeyEventResult.ignored;
              handlerFired++;
              return KeyEventResult.handled;
            },
            child: Column(
              children: [
                TextField(focusNode: textFieldFocus, controller: controller),
              ],
            ),
          ),
        ),
      ),
    );

    // Nothing has explicit focus yet beyond the autofocused ancestor Focus
    // node — a shortcut key should reach the handler.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(handlerFired, 1, reason: 'fires when no text field is focused');

    // Focus the answer field, as if the user tapped into it to type.
    textFieldFocus.requestFocus();
    await tester.pump();

    // A letter that could legitimately be part of a typed answer must NOT
    // reach the shortcut handler while the field is focused.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(
      handlerFired,
      1,
      reason: 'must not fire while a TextField has focus',
    );

    // Arrow keys (used for in-field cursor movement) must likewise not
    // reach the handler while the field is focused.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      handlerFired,
      1,
      reason: 'must not fire for arrow keys while typing either',
    );

    // Moving focus explicitly back to the ancestor (e.g. the field lost
    // focus when the study screen advanced to the next card) restores
    // normal shortcut handling.
    ancestorFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(handlerFired, 2, reason: 'resumes once the field loses focus');
  });

  // Verifies the Enter-defers-to-a-focused-button behaviour a revealed
  // multiple-choice question relies on: the study screen's Enter handler must
  // stand down while an option button has focus so Flutter's root-level
  // Activate shortcut can select the option, rather than the handler eating
  // Enter and advancing the card. The guard is the same ancestor walk as the
  // text-field one — checked here because a plain `is` check would silently
  // never match (the focused context's widget is the Focus the button wraps
  // itself in, not the OutlinedButton).
  testWidgets('Enter activates a focused button instead of the ancestor '
      'handler', (tester) async {
    var advanceFired = 0;
    var optionActivated = 0;
    final ancestorFocus = FocusNode();
    final optionFocus = FocusNode();
    addTearDown(() {
      ancestorFocus.dispose();
      optionFocus.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: ancestorFocus,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                final buttonFocused =
                    FocusManager.instance.primaryFocus?.context
                        ?.findAncestorWidgetOfExactType<OutlinedButton>() !=
                    null;
                if (buttonFocused) return KeyEventResult.ignored;
                advanceFired++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                OutlinedButton(
                  focusNode: optionFocus,
                  onPressed: () => optionActivated++,
                  child: const Text('Option A'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // No option focused yet — Enter should advance the card.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(advanceFired, 1, reason: 'advances when no option is focused');
    expect(optionActivated, 0);

    // Auto-focus the option (as a revealed MC question does), then Enter must
    // select it and leave the card where it is.
    optionFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(advanceFired, 1, reason: 'must not advance while an option focused');
    expect(optionActivated, 1, reason: 'Enter selects the focused option');
  });
}
