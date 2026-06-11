import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/feedback_item.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/feedback_provider.dart';
import 'package:flash_me/services/help_service.dart';
import 'package:flash_me/utils/helpers.dart';

// Dialog for submitting feedback or issue reports to the feedback/ Firestore
// collection. Carries the screen context (HelpContext) so submissions can be
// filtered by where in the app they were created.
class FeedbackDialog extends ConsumerStatefulWidget {
  const FeedbackDialog({required this.helpContext, super.key});

  final HelpContext helpContext;

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  FeedbackType _type = FeedbackType.feedback;
  bool _includeLogs = false;
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // Resolve the current runtime platform to a human-readable string.
  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) return;

    final user = ref.read(appUserProvider).asData?.value;
    final uid = ref.read(authStateProvider).asData?.value ?? '';

    setState(() => _isSending = true);
    try {
      final item = FeedbackItem(
        userId: uid,
        userEmail: user?.email ?? '',
        displayName: user?.displayName ?? '',
        context: widget.helpContext.name,
        type: _type,
        subject: subject,
        body: body,
        platform: _platform,
        timestamp: DateTime.now(),
        logs: _includeLogs ? LogBuffer().dump() : null,
      );
      await ref.read(feedbackRepositoryProvider).submit(item);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you — your report has been sent.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not send report. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_isSending &&
        _subjectController.text.trim().isNotEmpty &&
        _bodyController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Send Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Feedback vs Issue toggle.
            SegmentedButton<FeedbackType>(
              segments: const [
                ButtonSegment(
                  value: FeedbackType.feedback,
                  label: Text('Feedback'),
                  icon: Icon(Icons.rate_review_outlined),
                ),
                ButtonSegment(
                  value: FeedbackType.issue,
                  label: Text('Issue'),
                  icon: Icon(Icons.bug_report_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) =>
                  setState(() => _type = s.first),
              style: const ButtonStyle(
                  visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _includeLogs,
              onChanged: (v) => setState(() => _includeLogs = v ?? false),
              title: const Text('Include app logs'),
              subtitle: const Text('Helps diagnose technical issues'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSend ? _send : null,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
