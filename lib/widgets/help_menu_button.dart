import 'package:flutter/material.dart';
import '../services/help_service.dart';
import 'feedback_dialog.dart';

// Re-export so callers only need one import for both HelpMenuButton and HelpContext.
export '../services/help_service.dart' show HelpContext;

// An extra action that a screen can inject into the top of the HelpMenuButton's
// overflow menu — e.g. toolbar buttons that collapse in on a narrow layout.
class HelpMenuAction {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onSelected;
  const HelpMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });
}

// Overflow (⋮) AppBar button with Help and Send Report actions. Screens can pass
// [extraActions] to prepend their own items (above a divider) — this is the one
// overflow menu, so collapsed toolbar buttons should route here rather than
// spawning a second ⋮. Drop into an AppBar's actions: HelpMenuButton(context.xxx)
class HelpMenuButton extends StatelessWidget {
  const HelpMenuButton(this.helpContext, {super.key, this.extraActions = const []});

  final HelpContext helpContext;
  final List<HelpMenuAction> extraActions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value.startsWith('extra_')) {
          extraActions[int.parse(value.substring(6))].onSelected();
          return;
        }
        switch (value) {
          case 'help':
            HelpService.launch(helpContext);
          case 'report':
            showDialog(
              context: context,
              builder: (_) => FeedbackDialog(helpContext: helpContext),
            );
        }
      },
      itemBuilder: (_) => [
        // Injected screen actions first, then a divider before Help/Report.
        for (var i = 0; i < extraActions.length; i++)
          PopupMenuItem(
            value: 'extra_$i',
            enabled: extraActions[i].enabled,
            child: Row(children: [
              Icon(extraActions[i].icon),
              const SizedBox(width: 12),
              Text(extraActions[i].label),
            ]),
          ),
        if (extraActions.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'help',
          child: Row(children: [
            Icon(Icons.help_outline),
            SizedBox(width: 12),
            Text('Help'),
          ]),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(children: [
            Icon(Icons.rate_review_outlined),
            SizedBox(width: 12),
            Text('Send Report'),
          ]),
        ),
      ],
    );
  }
}
