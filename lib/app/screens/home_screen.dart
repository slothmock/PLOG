import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_donation_buttons/donationButtons/ko-fiButton.dart';
import 'package:flutter_donation_buttons/flutter_donation_buttons.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';

import 'package:sloth_ledger/app/screens/settings_screen.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';
import 'package:sloth_ledger/app/widgets/balance_card.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

import 'package:sloth_ledger/domain/accounts/account_enums.dart';

import 'package:sloth_ledger/features/ledger/ledger.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionStateProvider).ensureMinLoaded(10);
      ref.read(balanceStateProvider).load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final txnState = ref.read(transactionStateProvider);
      await txnState.ensureCoversMonth(DateTime.now());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      ref.read(transactionStateProvider).refreshAll(),
      ref.read(settingsStateProvider).load(force: true),
      ref.read(balanceStateProvider).load(force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountStateProvider);
    final txnState = ref.watch(transactionStateProvider);
    final settingsState = ref.watch(settingsStateProvider);
    final balances = ref.watch(balanceStateProvider);

    final settings = settingsState.settings;
    final recentTxns = txnState.recent(limit: 5);
    final collapsedRecent = collapseTransfers(recentTxns, accountState);

    final cashTotal = balances.totalFor(
      currencyCode: 'GBP',
      category: AccountCategory.fiat,
    );

    log.d(
      'HomeScreen build: cash=$cashTotal, recentTxns=${recentTxns.length}, settings=${settingsState.settings}',
    );

    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.only(top: 64),
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text(AppStrings.appName),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Balance row (simple, clean)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: BalanceCard(
                            label: AppStrings.totalCashLabel,
                            amount: cashTotal,
                            currencySymbol: settings.currencySymbol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Subtle divider to separate "summary" from content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      height: 0.5,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                // Recent transactions card
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppStrings.recentTransactions,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (!txnState.allLoaded && txnState.loading)
                              const SizedBox(
                                height: 140,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (txnState.errorMessage != null &&
                                recentTxns.isEmpty)
                              Text(
                                txnState.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              )
                            else if (recentTxns.isEmpty)
                              const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text(
                                    AppStrings.noRecentTransactionsTitle,
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: collapsedRecent
                                    .map(
                                      (txn) => TransactionRow(
                                        txn: txn,
                                        currencySymbol: settings.currencySymbol,
                                        showAccountName: false,
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 32,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        KofiButton(
                          text: AppStrings.supportSlothKofi,
                          kofiName: "slothmock",
                          kofiColor: KofiColor.Orange,
                          onDonation: () => CustomInfoToast.show(
                            context,
                            message: AppStrings.thanksForSupport,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
