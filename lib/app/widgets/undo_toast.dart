import 'package:flutter/material.dart';
import 'package:sloth_ledger/app/widgets/toast_overlay_host.dart';

class UndoToast {
  static Future<bool> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    String actionLabel = 'UNDO',
    bool showAtTop = false,
  }) {
    return showCustomToastOverlay<bool>(
      context,
      duration: duration,
      defaultResult: false,
      showAtTop: showAtTop,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      maxWidth: 520,
      builder: (ctx, close) => _UndoToastCard(
        message: message,
        actionLabel: actionLabel,
        onUndo: () => close(true),
        onDismiss: () => close(false),
      ),
    );
  }
}

class _UndoToastCard extends StatelessWidget {
  const _UndoToastCard({
    required this.message,
    required this.actionLabel,
    required this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onUndo, child: Text(actionLabel)),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
