import 'package:flutter/material.dart';
import '../services/help_service.dart';

// Re-export so callers only need one import for both HelpMenuButton and HelpContext.
export '../services/help_service.dart' show HelpContext;

// Overflow (⋮) AppBar button that opens the help site at a context-specific page.
// Drop this into any AppBar's actions list: HelpMenuButton(HelpContext.xxx)
class HelpMenuButton extends StatelessWidget {
  const HelpMenuButton(this.helpContext, {super.key});

  final HelpContext helpContext;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'help') HelpService.launch(helpContext);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'help',
          child: Row(
            children: [
              Icon(Icons.help_outline),
              SizedBox(width: 12),
              Text('Help'),
            ],
          ),
        ),
      ],
    );
  }
}
