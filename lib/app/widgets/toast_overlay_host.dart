import 'dart:async';

import 'package:flutter/material.dart';

typedef CustomToastBuilder<T> =
    Widget Function(BuildContext context, void Function(T result) close);

Future<void> showToastOverlay(
  BuildContext context, {
  required String message,
  required Duration duration,
  required Color backgroundColor,
  bool showAtTop = false,
  bool dismissOnTapOutside = true,
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16.0),
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  ),
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(8.0),
  ),
  TextStyle textStyle = const TextStyle(color: Colors.white),
  double? maxWidth,
}) {
  return showCustomToastOverlay<void>(
    context,
    duration: duration,
    defaultResult: null,
    showAtTop: showAtTop,
    dismissOnTapOutside: dismissOnTapOutside,
    margin: margin,
    maxWidth: maxWidth,
    builder: (ctx, close) => _MessageToastCard(
      message: message,
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      textStyle: textStyle,
    ),
  );
}

Future<T> showCustomToastOverlay<T>(
  BuildContext context, {
  required Duration duration,
  required T defaultResult,
  required CustomToastBuilder<T> builder,
  bool showAtTop = false,
  bool dismissOnTapOutside = true,
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16.0),
  double? maxWidth,
  bool animate = true,
}) {
  final overlay =
      Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
      Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) {
    return Future.value(defaultResult);
  }

  final completer = Completer<T>();
  OverlayEntry? entry;
  Timer? timer;

  void close([T? result]) {
    if (completer.isCompleted) return;
    timer?.cancel();
    entry?.remove();
    completer.complete(result ?? defaultResult);
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final mediaPadding = MediaQuery.of(ctx).padding;
      final top = mediaPadding.top + 12.0;
      final bottom = mediaPadding.bottom + 12.0;

      return _ToastOverlay<T>(
        onDismiss: () => close(defaultResult),
        close: close,
        showAtTop: showAtTop,
        dismissOnTapOutside: dismissOnTapOutside,
        topOffset: top,
        bottomOffset: bottom,
        margin: margin,
        maxWidth: maxWidth,
        animate: animate,
        builder: builder,
      );
    },
  );

  overlay.insert(entry);
  timer = Timer(duration, () => close(defaultResult));

  return completer.future;
}

class _ToastOverlay<T> extends StatefulWidget {
  const _ToastOverlay({
    required this.onDismiss,
    required this.close,
    required this.showAtTop,
    required this.dismissOnTapOutside,
    required this.topOffset,
    required this.bottomOffset,
    required this.margin,
    required this.maxWidth,
    required this.animate,
    required this.builder,
  });

  final VoidCallback onDismiss;
  final void Function(T result) close;
  final bool showAtTop;
  final bool dismissOnTapOutside;
  final double topOffset;
  final double bottomOffset;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;
  final bool animate;
  final CustomToastBuilder<T> builder;

  @override
  State<_ToastOverlay<T>> createState() => _ToastOverlayState<T>();
}

class _ToastOverlayState<T> extends State<_ToastOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder(context, widget.close);
    final positionedContent = Positioned(
      top: widget.showAtTop ? widget.topOffset : null,
      bottom: widget.showAtTop ? null : widget.bottomOffset,
      left: 0,
      right: 0,
      child: Padding(
        padding: widget.margin,
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth ?? double.infinity,
            ),
            child: widget.animate
                ? FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: widget.showAtTop
                                ? const Offset(0, -0.08)
                                : const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _controller,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: content,
                    ),
                  )
                : content,
          ),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (widget.dismissOnTapOutside)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
          positionedContent,
        ],
      ),
    );
  }
}

class _MessageToastCard extends StatelessWidget {
  const _MessageToastCard({
    required this.message,
    required this.padding,
    required this.borderRadius,
    required this.backgroundColor,
    required this.textStyle,
  });

  final String message;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color backgroundColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Text(message, style: textStyle),
      ),
    );
  }
}
