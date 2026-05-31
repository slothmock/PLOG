import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';

import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/ledger.dart';

enum _AccountMetricMode { balance, netContrib }

_AccountMetricMode _metricModeFor(SlothAccount a) {
  switch (a.category) {
    case AccountCategory.asset:
    case AccountCategory.liability:
      return _AccountMetricMode.balance;
  }
}

String _metricLabelTitle(_AccountMetricMode mode) {
  switch (mode) {
    case _AccountMetricMode.balance:
      return 'Balance';
    case _AccountMetricMode.netContrib:
      return 'Net contributions';
  }
}

String _metricLabelOpening(_AccountMetricMode mode) {
  switch (mode) {
    case _AccountMetricMode.balance:
      return 'Opening';
    case _AccountMetricMode.netContrib:
      return 'Opening value';
  }
}

String _metricLabelCurrent(_AccountMetricMode mode) {
  switch (mode) {
    case _AccountMetricMode.balance:
      return 'Current';
    case _AccountMetricMode.netContrib:
      return 'Net';
  }
}

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.account});

  final SlothAccount account;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccountHistory());
  }

  @override
  void didUpdateWidget(covariant AccountDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadAccountHistory(),
      );
    }
  }

  Future<void> _loadAccountHistory() async {
    if (!mounted) return;
    final accountId = widget.account.id;
    if (accountId == null) return;

    final txns = ref.read(transactionStateProvider);
    await txns.loadFiltered(accountId: accountId);
    await txns.ensureAllLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _metricModeFor(widget.account);

    final txnState = ref.watch(transactionStateProvider);

    final balances = ref.watch(balanceStateProvider);
    final settings = ref.read(settingsStateProvider).settings;
    final currencySymbol = balances.accountBalances[widget.account.id!] != null
        ? settings.currencySymbol
        : widget.account.currency;

    final currentMetric =
        balances.accountBalances[widget.account.id!] ??
        widget.account.openingBalance;

    final txnsAsc = List<SlothTransaction>.of(
      txnState.allForAccount(widget.account.id!),
    )..sort((a, b) => a.date.compareTo(b.date));

    final inTotal = txnsAsc
        .where((t) => t.amount > 0)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final outTotalAbs = txnsAsc
        .where((t) => t.amount < 0)
        .fold<double>(0, (sum, t) => sum + t.amount.abs());

    final netTotal = txnsAsc.fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(title: Text(widget.account.name)),
      body: Column(
        children: [
          _Header(
            account: widget.account,
            mode: mode,
            openingValue: widget.account.openingBalance,
            currentValue: currentMetric,
            currencySymbol: currencySymbol,
            inTotal: inTotal,
            outTotalAbs: outTotalAbs,
            netTotal: netTotal,
          ),
          const Divider(height: 1),
          Expanded(
            child: _TxnList(
              account: widget.account,
              mode: mode,
              txnsAsc: txnsAsc,
              currencySymbol: currencySymbol,
              loading: txnState.loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.account,
    required this.mode,
    required this.openingValue,
    required this.currentValue,
    required this.currencySymbol,
    required this.inTotal,
    required this.outTotalAbs,
    required this.netTotal,
  });

  final SlothAccount account;
  final _AccountMetricMode mode;

  final double openingValue;
  final double currentValue;
  final String currencySymbol;

  final double inTotal;
  final double outTotalAbs;
  final double netTotal;

  @override
  Widget build(BuildContext context) {
    final titleLabel = _metricLabelTitle(mode);
    final balColor = currentValue < 0 ? Colors.red : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${account.name} - $titleLabel: ${account.currency} ${currentValue.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: balColor,
            ),
          ),
          const SizedBox(height: 6),
          Text('${account.categoryLabel} • ${account.typeLabel}'),
          const SizedBox(height: 12),

          // Opening / Current stats
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: _metricLabelOpening(mode),
                  value: '$currencySymbol${openingValue.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: _metricLabelCurrent(mode),
                  value: '$currencySymbol${currentValue.toStringAsFixed(2)}',
                  valueColor: balColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'In',
                  value: '$currencySymbol${inTotal.toStringAsFixed(2)}',
                  valueColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Out',
                  value: '$currencySymbol${outTotalAbs.toStringAsFixed(2)}',
                  valueColor: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Net',
                  value: '$currencySymbol${netTotal.toStringAsFixed(2)}',
                  valueColor: netTotal < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _TxnList extends StatelessWidget {
  const _TxnList({
    required this.account,
    required this.mode,
    required this.txnsAsc,
    required this.currencySymbol,
    required this.loading,
  });

  final SlothAccount account;
  final _AccountMetricMode mode;
  final List<SlothTransaction> txnsAsc;
  final String currencySymbol;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && txnsAsc.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (txnsAsc.isEmpty) {
      return const Center(child: Text(AppStrings.noTransactionsYetTitle));
    }

    final showRunning = mode == _AccountMetricMode.balance;
    double running = account.openingBalance;

    return SafeArea(
      child: ListView.separated(
        itemCount: txnsAsc.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final txn = txnsAsc[i];
          running += txn.amount;

          return AccountTxnRow(
            txn: txn,
            currencySymbol: currencySymbol,
            runningBalance: showRunning ? running : null,
          );
        },
      ),
    );
  }
}
