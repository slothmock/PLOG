import 'dart:async';
import 'package:flutter/material.dart';

class UndoToast {
  static Future<bool> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    String actionLabel = 'UNDO',
    bool showAtTop = false,
  }) {
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);

    if (overlay == null) {
      return Future.value(false);
    }

    final completer = Completer<bool>();
    OverlayEntry? entry;
    Timer? timer;

    void close([bool undone = false]) {
      if (completer.isCompleted) return;
      timer?.cancel();
      entry?.remove();
      completer.complete(undone);
    }

    entry = OverlayEntry(
      builder: (ctx) {
        final padding = MediaQuery.of(ctx).padding;
        final top = padding.top + 12.0;
        final bottom = padding.bottom + 12.0;

        return _ToastOverlay(
          message: message,
          actionLabel: actionLabel,
          onUndo: () => close(true),
          onDismiss: () => close(false),
          showAtTop: showAtTop,
          topOffset: top,
          bottomOffset: bottom,
        );
      },
    );

    overlay.insert(entry);

    timer = Timer(duration, () => close(false));

    return completer.future;
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.actionLabel,
    required this.onUndo,
    required this.onDismiss,
    required this.showAtTop,
    required this.topOffset,
    required this.bottomOffset,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;
  final bool showAtTop;
  final double topOffset;
  final double bottomOffset;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.showAtTop
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final offsetY = widget.showAtTop ? widget.topOffset : widget.bottomOffset;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          Align(
            alignment: alignment,
            child: Padding(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: widget.showAtTop ? offsetY : 0,
                bottom: widget.showAtTop ? 0 : offsetY,
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: widget.showAtTop
                        ? const Offset(0, -0.08)
                        : const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
                  child: _ToastCard(
                    message: widget.message,
                    actionLabel: widget.actionLabel,
                    onUndo: widget.onUndo,
                    onDismiss: widget.onDismiss,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
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
      ),
    );
  }
}
