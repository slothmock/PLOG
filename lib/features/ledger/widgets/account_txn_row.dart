import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/ledger.dart';


class AccountTxnRow extends ConsumerWidget {
  const AccountTxnRow({
    super.key,
    required this.txn,
    required this.currencySymbol, this.runningBalance,
  });

  final double? runningBalance;
  final SlothTransaction txn;
  final String currencySymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = txn.isExpense;
    final dateStr = DateFormat.yMMMd().format(txn.date);

    return ListTile(
      leading: Icon(
        isExpense ? Icons.arrow_upward : Icons.arrow_downward,
        color: isExpense ? Colors.red : Colors.green,
      ),
      title: Text(txn.category),
      subtitle: Text(
        [
          dateStr,
          if (txn.notes != null && txn.notes!.trim().isNotEmpty)
            txn.notes!.trim(),
        ].join(' • '),
      ),
      trailing: Text(
        '$currencySymbol${txn.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isExpense ? Colors.red : Colors.green,
        ),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          builder: (_) => AddTransactionModal(transaction: txn),
        );
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This action can be undone for a short time.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref.read(transactionStateProvider).deleteWithUndo(context, txn);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }
}
