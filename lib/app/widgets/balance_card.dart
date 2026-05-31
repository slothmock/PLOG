import 'package:flutter/material.dart';
import 'package:sloth_ledger/app/utils/currency_formatter.dart';
import 'package:sloth_ledger/app/widgets/info_help_button.dart';

class BalanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;
  final IconData? icon;
  final String? helpTitle;
  final String? helpTooltip;
  final List<String>? helpLines;

  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    required this.currencySymbol,
    this.icon,
    this.helpTitle,
    this.helpTooltip,
    this.helpLines,
  });

  @override
  Widget build(BuildContext context) {
    final helpTitle = this.helpTitle;
    final helpLines = this.helpLines;

    return Card(
      elevation: 3,
      child: SizedBox(
        height: 92,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.black38),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                    if (helpTitle != null && helpLines != null)
                      InfoHelpButton(
                        title: helpTitle,
                        lines: helpLines,
                        tooltip: helpTooltip,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyFormatter.compact(amount, symbol: currencySymbol),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isNegative(amount) ? Colors.red : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool isNegative(double amount) {
  return amount < 0;
}
