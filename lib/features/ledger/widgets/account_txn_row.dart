import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/modals/add_transaction_modal.dart';
import 'package:sloth_ledger/features/ledger/widgets/transaction_row_helpers.dart';

class AccountTxnRow extends ConsumerWidget {
  const AccountTxnRow({
    super.key,
    required this.txn,
    required this.currencySymbol,
    this.runningBalance,
  });

  final double? runningBalance;
  final SlothTransaction txn;
  final String currencySymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.yMMMd().format(txn.date);

    return ListTile(
      leading: Icon(
        transactionDirectionIcon(txn),
        color: transactionDirectionColor(txn),
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
        formatTransactionAmount(txn, currencySymbol),
        style: transactionAmountTextStyle(txn),
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
        showDeleteTransactionDialog(context: context, ref: ref, txn: txn);
      },
    );
  }
}
