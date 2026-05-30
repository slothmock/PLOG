import 'package:flutter/material.dart';

class InfoHelpButton extends StatelessWidget {
  const InfoHelpButton({
    super.key,
    required this.title,
    required this.lines,
    this.tooltip,
  });

  final String title;
  final List<String> lines;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? title,
      icon: const Icon(Icons.info_outline, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  Text(lines[i]),
                  if (i < lines.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }
}
