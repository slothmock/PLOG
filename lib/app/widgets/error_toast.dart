import 'package:flutter/material.dart';
import 'package:sloth_ledger/app/widgets/toast_overlay_host.dart';

class ErrorToast {
  static Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    bool showAtTop = false,
  }) {
    return showToastOverlay(
      context,
      message: message,
      duration: duration,
      showAtTop: showAtTop,
      backgroundColor: Colors.red.shade600,
    );
  }
}
