import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/widgets/undo_toast.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';

bool isTransferTransaction(SlothTransaction txn) {
  return txn.isTransfer || txn.category == 'Transfer';
}

IconData transactionDirectionIcon(
  SlothTransaction txn, {
  bool includeTransfers = false,
}) {
  if (includeTransfers && isTransferTransaction(txn)) {
    return Icons.swap_horiz;
  }

  return txn.isExpense ? Icons.arrow_upward : Icons.arrow_downward;
}

Color transactionDirectionColor(
  SlothTransaction txn, {
  bool includeTransfers = false,
}) {
  if (includeTransfers && isTransferTransaction(txn)) {
    return Colors.blueGrey;
  }

  return txn.isExpense ? Colors.red : Colors.green;
}

String formatTransactionAmount(SlothTransaction txn, String currencySymbol) {
  return '$currencySymbol${txn.amount.toStringAsFixed(2)}';
}

TextStyle transactionAmountTextStyle(
  SlothTransaction txn, {
  bool includeTransfers = false,
  double? fontSize,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: transactionDirectionColor(txn, includeTransfers: includeTransfers),
  );
}

Future<void> deleteTransactionWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SlothTransaction txn,
}) async {
  final undoToastContext = Navigator.of(context, rootNavigator: true).context;
  final transactionState = ref.read(transactionStateProvider);

  final result = await transactionState.deleteForUndo(txn);
  if (!result.deleted || !undoToastContext.mounted) return;

  final undone = await UndoToast.show(
    undoToastContext,
    message: result.undoMessage,
    duration: const Duration(seconds: 4),
    showAtTop: true,
  );

  if (undone) {
    await transactionState.restoreDeleted(result);
  }
}

Future<void> showDeleteTransactionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required SlothTransaction txn,
}) {
  return showDialog<void>(
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
          onPressed: () async {
            Navigator.pop(dialogContext);
            await deleteTransactionWithUndo(
              context: context,
              ref: ref,
              txn: txn,
            );
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
