import 'package:flutter/material.dart';

// A single entry in a right-click context menu (#237). Kept separate from
// [HelpMenuAction] (help_menu_button.dart) because context menus need
// [destructive] styling (a red Delete grouped below a divider) that the ⋮
// Help menu's actions never do.
class ContextMenuAction {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool destructive;
  final VoidCallback onSelected;
  const ContextMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
    this.destructive = false,
  });
}

// Shows a right-click context menu at [position] (a right-click's global
// coordinates) with [actions]. Non-destructive actions come first; any
// destructive ones (e.g. Delete) are grouped below a divider and styled in the
// theme's error colour, matching the styling convention already used for
// destructive buttons elsewhere in the app (delete confirmation dialogs).
Future<void> showContextMenu(
  BuildContext context,
  Offset position,
  List<ContextMenuAction> actions,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final errorColor = Theme.of(context).colorScheme.error;
  final normal = actions.where((a) => !a.destructive).toList();
  final destructive = actions.where((a) => a.destructive).toList();

  final selected = await showMenu<VoidCallback>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final a in normal)
        PopupMenuItem<VoidCallback>(
          value: a.onSelected,
          enabled: a.enabled,
          child: _actionRow(a),
        ),
      if (destructive.isNotEmpty) const PopupMenuDivider(),
      for (final a in destructive)
        PopupMenuItem<VoidCallback>(
          value: a.onSelected,
          enabled: a.enabled,
          child: _actionRow(a, color: errorColor),
        ),
    ],
  );
  selected?.call();
}

Widget _actionRow(ContextMenuAction action, {Color? color}) {
  return Row(
    children: [
      Icon(action.icon, color: color),
      const SizedBox(width: 12),
      Text(action.label, style: color != null ? TextStyle(color: color) : null),
    ],
  );
}
