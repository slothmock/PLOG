import 'dart:async';
import 'package:flutter/material.dart';

class CustomInfoToast {
  static Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    bool showAtTop = true,
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
      left: 24.0,
      right: 24.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
