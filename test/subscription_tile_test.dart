import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/data/repositories/subscriptions_repository.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription_enums.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';
import 'package:sloth_ledger/features/ledger/state/transaction_state.dart';
import 'package:sloth_ledger/features/subscriptions/state/subscriptions_state.dart';
import 'package:sloth_ledger/features/subscriptions/widgets/subscription_tile.dart';

void main() {
  testWidgets('mark paid action refreshes ledger transactions and balances', (
    tester,
  ) async {
    final sub = SlothSubscription(
      id: 1,
      name: 'Gym',
      amount: 12.99,
      currency: 'GBP',
      interval: SubscriptionInterval.monthly,
      nextDue: DateTime(2026, 2, 1),
      accountId: 1,
      isActive: true,
    );

    final balanceRepo = _CountingBalanceRepository();
    final balanceState = BalanceState(balanceRepo);
    final accountState = AccountState(
      _AccountRepository([
        SlothAccount(
          id: 1,
          name: 'Bank',
          category: AccountCategory.asset,
          type: AccountType.bank,
          currency: 'GBP',
          openingBalance: 100,
          createdAt: DateTime(2026),
        ),
      ]),
      balanceState,
    );
    await accountState.load();

    final txnRepo = _CountingTransactionRepository();
    final txnState = TransactionState(txnRepo, balanceState);
    final subscriptionState = SubscriptionState(_SubscriptionRepository([sub]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountStateProvider.overrideWith((ref) => accountState),
          balanceStateProvider.overrideWith((ref) => balanceState),
          transactionStateProvider.overrideWith((ref) => txnState),
          subscriptionStateProvider.overrideWith((ref) => subscriptionState),
        ],
        child: MaterialApp(
          home: Scaffold(body: SubscriptionTile(sub: sub)),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();

    expect(txnRepo.fetchPageCalls, 1);
    expect(balanceRepo.fetchCalls, 1);

    await tester.pump(const Duration(seconds: 4));
  });
}

class _SubscriptionRepository extends SubscriptionRepository {
  _SubscriptionRepository(this.subscriptions);

  final List<SlothSubscription> subscriptions;

  @override
  Future<List<SlothSubscription>> fetchAll({bool activeOnly = false}) async {
    return subscriptions;
  }

  @override
  Future<void> markPaid({
    required SlothSubscription sub,
    DateTime? paidAt,
    double? amountOverride,
    String? notes,
    int? txnId,
  }) async {}
}

class _CountingTransactionRepository extends TransactionRepository {
  int fetchPageCalls = 0;

  @override
  Future<List<SlothTransaction>> fetchPage({
    required int limit,
    required int offset,
    int? accountId,
    String? category,
    String? searchQuery,
  }) async {
    fetchPageCalls++;
    return const [];
  }
}

class _CountingBalanceRepository extends BalanceRepository {
  int fetchCalls = 0;

  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async {
    fetchCalls++;
    return const [];
  }
}

class _AccountRepository extends AccountRepository {
  _AccountRepository(this.accounts);

  final List<SlothAccount> accounts;

  @override
  Future<List<SlothAccount>> fetchAll() async => accounts;
}
