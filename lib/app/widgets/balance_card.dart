import 'package:flutter/material.dart';
import 'package:sloth_ledger/app/utils/currency_formatter.dart';

class BalanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;
  final IconData? icon;

  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    required this.currencySymbol,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.black38),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.compact(amount, symbol: currencySymbol),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isNegative(amount) ? Colors.red : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool isNegative(double amount) {
  return amount < 0;
}
