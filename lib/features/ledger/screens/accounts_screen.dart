import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';
import 'package:sloth_ledger/app/widgets/info_help_button.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/features/ledger/screens/account_details_screen.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

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

    final assetAccounts = widget.state.accounts
        .where((account) => account.category == AccountCategory.asset)
        .toList();
    final liabilityAccounts = widget.state.accounts
        .where((account) => account.category == AccountCategory.liability)
        .toList();

    return SafeArea(
      child: ListView(
        children: [
          _SectionHeader(
            label: AccountCategory.asset.label,
            helpTitle: 'Assets',
            helpTooltip: 'What are assets?',
            helpLines: const [
              'Money or accounts you own.',
              'Examples: cash, current accounts, and savings.',
              'If a bank account is overdrawn, keep it here and enter the balance as negative.',
            ],
          ),
          if (assetAccounts.isEmpty)
            const _EmptySectionMessage(
              title: 'No asset accounts yet',
              detail: 'Cash and bank accounts appear here.',
            )
          else
            ...assetAccounts.map((acc) => _accountTile(context, balances, acc)),
          _SectionHeader(
            label: AccountCategory.liability.label,
            helpTitle: 'Liabilities',
            helpTooltip: 'What are liabilities?',
            helpLines: const [
              'Money you owe.',
              'Examples: credit cards, loans, mortgages, and finance agreements.',
              'Enter the amount owed as a positive number; PLOG subtracts it from net worth.',
            ],
          ),
          if (liabilityAccounts.isEmpty)
            const _EmptySectionMessage(
              title: 'No liability accounts yet',
              detail:
                  'Credit cards, loans, mortgages, and finance agreements appear here.',
            )
          else
            ...liabilityAccounts.map(
              (acc) => _accountTile(context, balances, acc),
            ),
        ],
      ),
    );
  }

  Widget _accountTile(
    BuildContext context,
    BalanceState balances,
    SlothAccount acc,
  ) {
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
        style: const TextStyle(fontStyle: FontStyle.italic),
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
          MaterialPageRoute(builder: (_) => AccountDetailScreen(account: acc)),
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
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.helpTitle,
    this.helpTooltip,
    this.helpLines,
  });

  final String label;
  final String? helpTitle;
  final String? helpTooltip;
  final List<String>? helpLines;

  @override
  Widget build(BuildContext context) {
    final helpTitle = this.helpTitle;
    final helpLines = this.helpLines;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (helpTitle != null && helpLines != null)
            InfoHelpButton(
              title: helpTitle,
              lines: helpLines,
              tooltip: helpTooltip,
            ),
        ],
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colourScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colourScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colourScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colourScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colourScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
