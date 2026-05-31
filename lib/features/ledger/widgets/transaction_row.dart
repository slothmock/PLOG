import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/modals/transaction_detail_modal.dart';
import 'package:sloth_ledger/features/ledger/utils/relative_labels.dart';
import 'package:sloth_ledger/features/ledger/widgets/transaction_row_helpers.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.txn,
    required this.currencySymbol,
    this.showAccountName = true,
    this.dense = false,
    this.enableDelete = true,
  });

  final SlothTransaction txn;
  final String currencySymbol;

  final bool showAccountName;
  final bool dense;
  final bool enableDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountStateProvider);
    final accountName =
        accountState.byId(txn.accountId)?.name ?? 'Account ${txn.accountId}';

    final dateStr = relativeDateTimeLabel(txn.date);

    final isTransfer = isTransferTransaction(txn);
    final icon = transactionDirectionIcon(txn, includeTransfers: true);
    final iconColor = transactionDirectionColor(txn, includeTransfers: true);

    final merchant = txn.merchant?.trim();
    final title = isTransfer
        ? ((txn.merchant?.trim().isNotEmpty ?? false)
              ? txn.merchant!.trim()
              : 'Transfer')
        : ((merchant != null && merchant.isNotEmpty) ? merchant : txn.category);

    final subtitleLine1Parts = <String>[
      dateStr,
      if (showAccountName) accountName,
      if (!isTransfer) txn.category,
    ];
    final subtitleLine1 = subtitleLine1Parts.join(' • ');

    final notes = txn.notes?.trim();
    final subtitleLine2 = (notes != null && notes.isNotEmpty) ? notes : null;

    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: dense ? 1 : 2,
      ),
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitleLine1, style: const TextStyle(fontSize: 13)),
          if (subtitleLine2 != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitleLine2,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Text(
        formatTransactionAmount(txn, currencySymbol),
        style: transactionAmountTextStyle(
          txn,
          includeTransfers: true,
          fontSize: dense ? 12.5 : 14.0,
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
          builder: (_) =>
              TransactionDetailModal(txn: txn, hostContext: context),
        );
      },
      onLongPress: enableDelete
          ? () {
              showDeleteTransactionDialog(context: context, ref: ref, txn: txn);
            }
          : null,
    );
  }
}
