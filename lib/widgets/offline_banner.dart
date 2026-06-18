import 'package:flutter/material.dart';
import 'package:flash_me/utils/extensions.dart';

// Pure UI widget. Visibility is controlled by the root MaterialApp builder —
// this widget just renders the strip content and is never shown when online.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.l10n.messageOfflineBanner,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
