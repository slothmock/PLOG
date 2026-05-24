import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/modals/add_transaction_modal.dart';

class TransactionDetailModal extends ConsumerStatefulWidget {
  const TransactionDetailModal({
    super.key,
    required this.txn,
    required this.hostContext,
  });
  final SlothTransaction txn;
  final BuildContext hostContext;

  @override
  ConsumerState<TransactionDetailModal> createState() =>
      _TransactionDetailModalState();
}

class _TransactionDetailModalState
    extends ConsumerState<TransactionDetailModal> {
  @override
  Padding build(BuildContext context) {
    final title = (widget.txn.merchant?.trim().isNotEmpty ?? false)
        ? widget.txn.merchant!.trim()
        : widget.txn.category;
    final symbol = ref.watch(settingsStateProvider).settings.currencySymbol;
    final accountName =
        ref.watch(accountStateProvider).byId(widget.txn.accountId)?.name ??
        'Account ${widget.txn.accountId}';

    final dt = DateFormat.yMMMMd().add_jm().format(widget.txn.date);
    final isExpense = widget.txn.isExpense;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              Row(
                children: [
                  Icon(
                    isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$symbol${widget.txn.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),

              _kv('Account', accountName),
              _kv('Date', dt),
              if ((widget.txn.notes ?? '').trim().isNotEmpty)
                _kv('Notes', widget.txn.notes!.trim()),
              if (widget.txn.isTransfer) _kv('Transfer', 'Yes'),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('Edit'),
                      onPressed: () async {
                        Navigator.pop(context);

                        await showModalBottomSheet(
                          context: widget.hostContext,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          builder: (_) =>
                              AddTransactionModal(transaction: widget.txn),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: () async {
                        final navigator = Navigator.of(
                          widget.hostContext,
                          rootNavigator: true,
                        );

                        Navigator.pop(context);

                        await ref
                            .read(transactionStateProvider)
                            .deleteWithUndo(navigator.context, widget.txn);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
