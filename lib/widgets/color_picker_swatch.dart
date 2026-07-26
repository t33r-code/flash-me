import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ColorPickerSwatch — one keyboard-focusable colour option in a swatch picker
// (#235). FocusableActionDetector gives it a focus node + tab-traversal and
// maps Enter/Space (ActivateIntent) to [onTap]; a GestureDetector handles mouse
// taps. onShowFocusHighlight fires only for keyboard focus (not a mouse click),
// so the focus ring appears exactly when a keyboard user tabs onto the swatch.
// [color] == null renders the "no colour" option. [onTap] == null disables it.
// Named ColorPickerSwatch (not ColorSwatch) to avoid clashing with Flutter's
// built-in ColorSwatch type.
// ---------------------------------------------------------------------------
class ColorPickerSwatch extends StatefulWidget {
  final Color? color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback? onTap;

  const ColorPickerSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  State<ColorPickerSwatch> createState() => _ColorPickerSwatchState();
}

class _ColorPickerSwatchState extends State<ColorPickerSwatch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNone = widget.color == null;
    final enabled = widget.onTap != null;

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        // GestureDetector covers pointer taps; the Action above covers keyboard.
        child: GestureDetector(
          onTap: widget.onTap,
          // SizedBox expands the hit area to 48dp without changing the visual.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              // 44dp ring layer — only painted (primary border) while
              // keyboard-focused, so focus is clearly visible.
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: _focused
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isNone ? Colors.transparent : widget.color,
                      border: Border.all(
                        color: isNone ? scheme.outline : widget.color!,
                        width: widget.selected ? 3 : 1,
                      ),
                    ),
                    child: widget.selected
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: isNone ? scheme.onSurface : Colors.white,
                          )
                        // "None" option shows a slash icon when unselected.
                        : isNone
                        ? Icon(Icons.block, size: 18, color: scheme.outline)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
