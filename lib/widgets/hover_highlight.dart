import 'package:flutter/material.dart';

// Subtle hover tint for a tile/row (#237) — pointer-only by construction:
// MouseRegion only fires enter/exit for a mouse, so touch devices are
// unaffected without any platform check.
class HoverHighlight extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  const HoverHighlight({super.key, required this.child, this.borderRadius});

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _hovering
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
        child: widget.child,
      ),
    );
  }
}
