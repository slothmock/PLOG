import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

import 'package:sloth_ledger/domain/subscriptions/subscription.dart';
import 'package:sloth_ledger/features/subscriptions/widgets/add_subscription_modal.dart';


class SubscriptionDetailModal extends ConsumerStatefulWidget {
  const SubscriptionDetailModal({super.key, required this.sub});

  final SlothSubscription sub;

  @override
  ConsumerState<SubscriptionDetailModal> createState() => _SubscriptionDetailModalState();
}

class _SubscriptionDetailModalState extends ConsumerState<SubscriptionDetailModal> {
  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionStateProvider);
    bool activeSub = widget.sub.isActive;

    final accountName =
        ref.watch(accountStateProvider).byId(widget.sub.accountId)?.name ??
        'Account ${widget.sub.accountId}';

    final due = DateFormat.yMMMMd().format(widget.sub.nextDue);

    final busy = subState.loading;

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
                    widget.sub.isActive ? Icons.autorenew : Icons.pause_circle_outline,
                    color: widget.sub.isActive ? Colors.blueGrey : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sub.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),

              _kv('Amount', widget.sub.amount.toStringAsFixed(2)),
              _kv('Interval', widget.sub.interval.label),
              _kv('Next due', due),
              _kv('Paid from', accountName),
              _kv('Status', widget.sub.isActive ? 'Active' : 'Paused'),

              const SizedBox(height: 16),

              // Mark paid (primary)
              if (activeSub) 
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.teal,),
                  label: const Text('Mark as paid', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),),
                  onPressed: busy
                      ? null
                      : () async {

                          final ok = await ref
                              .read(subscriptionStateProvider)
                              .markPaid(sub: widget.sub);

                          if (!context.mounted) return;

                          if (!ok) {
                            final msg = ref
                                .read(subscriptionStateProvider)
                                .errorMessage ??
                                'Mark as paid failed';
                            if (!context.mounted) return;
                            CustomInfoToast.show(context, message: msg);
                            ref.read(subscriptionStateProvider).clearError();
                          } else {
                            if (!context.mounted) return;
                            CustomInfoToast.show(context, message: 'Marked as paid', duration: const Duration(seconds: 2));
                            await ref.read(accountStateProvider).load(force: true);
                            await ref.read(subscriptionStateProvider).load();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                ),
              ),
      
              const SizedBox(height: 12),

              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                builder: (_) =>
                                    AddSubscriptionModal(subscription: widget.sub),
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('Delete'),
                      onPressed: busy
                          ? null
                          : () async {
                              Navigator.pop(context);

                              final ok = await ref
                                  .read(subscriptionStateProvider)
                                  .delete(widget.sub.id!);

                              if (!context.mounted) return;

                              if (!ok) {
                                final msg = ref
                                        .read(subscriptionStateProvider)
                                        .errorMessage ??
                                    'Delete failed';
                                ErrorToast.show(context, message: msg);
                                ref.read(subscriptionStateProvider).clearError();
                              } else {
                                CustomInfoToast.show(context, message: 'Subscription deleted');
                              }
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
            width: 90,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}