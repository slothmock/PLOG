import 'dart:async';
import 'package:flutter/material.dart';

class ErrorToast {
  static Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    bool showAtTop = false,
  }) {
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);

    if (overlay == null) {
      return Future.value();
    }

    final completer = Completer<void>();
    OverlayEntry? entry;
    Timer? timer;

    void close() {
      if (completer.isCompleted) return;
      timer?.cancel();
      entry?.remove();
      completer.complete();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        final padding = MediaQuery.of(ctx).padding;
        final top = padding.top + 12.0;
        final bottom = padding.bottom + 12.0;

        return _ToastOverlay(
          message: message,
          onDismiss: close,
          showAtTop: showAtTop,
          topOffset: top,
          bottomOffset: bottom,
        );
      },
    );

    overlay.insert(entry);

    timer = Timer(duration, close);

    return completer.future;
  }
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.message,
    required this.onDismiss,
    required this.showAtTop,
    required this.topOffset,
    required this.bottomOffset,
  });

  final String message;
  final VoidCallback onDismiss;
  final bool showAtTop;
  final double topOffset;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: showAtTop ? topOffset : null,
      bottom: showAtTop ? null : bottomOffset,
      left: 16.0,
      right: 16.0,
      child: Material(
        color: Colors.red[600],
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
