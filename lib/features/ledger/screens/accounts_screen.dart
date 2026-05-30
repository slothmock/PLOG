import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/features/ledger/screens/account_details_screen.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';

import 'package:sloth_ledger/features/ledger/modals/transfer_modal.dart';
import 'package:sloth_ledger/app/widgets/add_account_modal.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _openAccountModal(BuildContext context, {SlothAccount? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AddAccountModal(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.accountsTitle)),
      body: _Body(
        state: state,
        onEdit: (acc) => _openAccountModal(context, account: acc),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.state, required this.onEdit});

  final AccountState state;
  final void Function(SlothAccount acc) onEdit;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(balanceStateProvider);

    // First-load spinner only if we have no cached data yet
    if (widget.state.loading && widget.state.accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.state.accounts.isEmpty) {
      return const Center(child: Text(AppStrings.noAccounts));
    }

    return SafeArea(
      child: ListView.builder(
        itemCount: widget.state.accounts.length,
        itemBuilder: (context, index) {
          final acc = widget.state.accounts[index];
          final accountBalance = (acc.id == null)
              ? acc.openingBalance
              : (balances.accountBalances[acc.id!] ?? acc.openingBalance);
          return ListTile(
            title: Text(
              '${acc.name}: ${accountBalance.toStringAsFixed(2)} ${acc.currency}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: accountBalance < 0 ? Colors.red : null,
              ),
            ),
            subtitle: Text(
              '${acc.categoryLabel} • ${acc.typeLabel}',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => widget.onEdit(acc),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final msg = await ref
                        .read(accountStateProvider)
                        .deleteWithRules(acc.id!);
                    if (msg != null && context.mounted) {
                      CustomInfoToast.show(context, message: msg);
                    }
                  },
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailScreen(account: acc),
                ),
              );
            },
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                builder: (_) => TransferModal(fromAccountId: acc.id),
              );
            },
          );
        },
      ),
    );
  }
}
