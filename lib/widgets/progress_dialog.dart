import 'package:flutter/material.dart';

// Shared "please wait" progress dialog — a barrier-blocking AlertDialog with a
// spinner + message, used for export/import/analyze operations that need to
// block interaction until a background Future completes (#287 RF-4). Caller
// is responsible for popping it (Navigator.of(context).pop()) once done.
void showProgressDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text(message),
        ],
      ),
    ),
  );
}
