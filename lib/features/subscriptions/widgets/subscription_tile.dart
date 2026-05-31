import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/app/utils/currency_formatter.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';
import 'package:sloth_ledger/features/subscriptions/logic/interval_helper.dart';
import 'package:sloth_ledger/features/subscriptions/widgets/subscription_detail_modal.dart';
import 'package:sloth_ledger/features/subscriptions/widgets/add_subscription_modal.dart';

class SubscriptionTile extends ConsumerStatefulWidget {
  const SubscriptionTile({super.key, required this.sub});

  final SlothSubscription sub;

  @override
  ConsumerState<SubscriptionTile> createState() => _SubscriptionTileState();
}

class _SubscriptionTileState extends ConsumerState<SubscriptionTile> {
  @override
  Widget build(BuildContext context) {
    final accountName =
        ref.watch(accountStateProvider).byId(widget.sub.accountId)?.name ??
        'Account ${widget.sub.accountId}';

    final due = DateFormat.yMMMd().format(widget.sub.nextDue);

    final amountText = CurrencyFormatter.compact(
      widget.sub.amount,
      symbol: widget.sub.currency,
    );

    final intervalLabel = intervalLabelHelper(widget.sub.interval.name);

    return ListTile(
      leading: Icon(
        widget.sub.isActive ? Icons.autorenew : Icons.pause_circle_outline,
        color: widget.sub.isActive ? Colors.teal : Colors.grey,
      ),
      title: Text(
        widget.sub.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$accountName • Next: $due • $intervalLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      // amount + menu
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amountText,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 6),
          _ActionsMenu(sub: widget.sub),
        ],
      ),

      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          builder: (_) => SubscriptionDetailModal(sub: widget.sub),
        );
      },
    );
  }
}

enum _SubAction { markPaid, snooze7, skipOnce, edit, delete }

class _ActionsMenu extends ConsumerStatefulWidget {
  const _ActionsMenu({required this.sub});
  final SlothSubscription sub;

  @override
  ConsumerState<_ActionsMenu> createState() => _ActionsMenuState();
}

class _ActionsMenuState extends ConsumerState<_ActionsMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SubAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        final rootCtx = Navigator.of(context, rootNavigator: true).context;
        final state = ref.watch(subscriptionStateProvider);

        Future<void> showMsg(String msg, {bool error = false}) async {
          error
              ? ErrorToast.show(rootCtx, message: msg)
              : CustomInfoToast.show(rootCtx, message: msg);
        }

        switch (action) {
          case _SubAction.markPaid:
            {
              if (!widget.sub.isActive) {
                await showMsg('Subscription is paused', error: true);
                return;
              }
              final ok = await ref
                  .read(subscriptionStateProvider)
                  .markPaid(sub: widget.sub); // implement in state
              if (!rootCtx.mounted) return;
              if (!ok) {
                await showMsg(
                  state.errorMessage ?? 'Mark paid failed',
                  error: true,
                );
                state.clearError();
              } else {
                await showMsg('Marked paid');
              }
              return;
            }

          case _SubAction.snooze7:
            {
              final ok = await ref
                  .read(subscriptionStateProvider)
                  .snooze(widget.sub, days: 7); // implement in state
              if (!rootCtx.mounted) return;
              if (!ok) {
                await showMsg(
                  state.errorMessage ?? 'Snooze failed',
                  error: true,
                );
                state.clearError();
              } else {
                await showMsg('Snoozed 7 days');
              }
              return;
            }

          case _SubAction.skipOnce:
            {
              final ok = await ref
                  .read(subscriptionStateProvider)
                  .skipOnce(widget.sub); // implement in state
              if (!rootCtx.mounted) return;
              if (!ok) {
                await showMsg(state.errorMessage ?? 'Skip failed', error: true);
                state.clearError();
              } else {
                await showMsg('Skipped once');
              }
              return;
            }

          case _SubAction.edit:
            {
              showModalBottomSheet(
                context: rootCtx,
                isScrollControlled: true,
                useSafeArea: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                builder: (_) => AddSubscriptionModal(subscription: widget.sub),
              );
              return;
            }

          case _SubAction.delete:
            {
              final confirm = await showDialog<bool>(
                context: rootCtx,
                builder: (d) => AlertDialog(
                  title: const Text('Delete subscription?'),
                  content: const Text('This will remove it from your list.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              final ok = await ref
                  .read(subscriptionStateProvider)
                  .delete(widget.sub.id!);
              if (!rootCtx.mounted) return;

              if (!ok) {
                await showMsg(
                  state.errorMessage ?? 'Delete failed',
                  error: true,
                );
                state.clearError();
              } else {
                await showMsg('Subscription deleted');
              }
              return;
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _SubAction.markPaid,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.check_circle_outline),
            title: Text('Mark paid'),
          ),
        ),
        const PopupMenuItem(
          value: _SubAction.snooze7,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.snooze),
            title: Text('Snooze 7 days'),
          ),
        ),
        const PopupMenuItem(
          value: _SubAction.skipOnce,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.fast_forward),
            title: Text('Skip once'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _SubAction.edit,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem(
          value: _SubAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }
}
