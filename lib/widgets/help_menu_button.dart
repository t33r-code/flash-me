import 'package:flutter/material.dart';
import '../services/help_service.dart';
import 'feedback_dialog.dart';

// Re-export so callers only need one import for both HelpMenuButton and HelpContext.
export '../services/help_service.dart' show HelpContext;

// Overflow (⋮) AppBar button with Help and Send Report actions.
// Drop this into any AppBar's actions list: HelpMenuButton(HelpContext.xxx)
class HelpMenuButton extends StatelessWidget {
  const HelpMenuButton(this.helpContext, {super.key});

  final HelpContext helpContext;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
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
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'help',
          child: Row(children: [
            Icon(Icons.help_outline),
            SizedBox(width: 12),
            Text('Help'),
          ]),
        ),
        PopupMenuItem(
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
