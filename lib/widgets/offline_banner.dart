import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/providers/connectivity_provider.dart';
import 'package:flash_me/utils/extensions.dart';

// Slim top strip shown app-wide when the device has no network connection.
// Wraps its content in SafeArea(bottom: false) so it sits flush against the
// status bar on notched devices without clipping the inner text.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();

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