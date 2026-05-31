import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/state/category_state.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/data/repositories/category_repository.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/screens/transactions_screen.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';
import 'package:sloth_ledger/features/ledger/state/transaction_state.dart';

void main() {
  testWidgets('clearing an account filter chip reloads the unfiltered ledger', (
    tester,
  ) async {
    final account = SlothAccount(
      id: 42,
      name: 'Bills',
      category: AccountCategory.asset,
      type: AccountType.bank,
      currency: 'GBP',
      openingBalance: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    final txnRepo = _RecordingTransactionRepository();
    final balanceState = BalanceState(_EmptyBalanceRepository());
    final accountState = AccountState(
      _StaticAccountRepository([account]),
      balanceState,
    );
    final categoryState = CategoryState(
      _StaticCategoryRepository(['Groceries']),
    );
    final transactionState = TransactionState(txnRepo, balanceState);

    await accountState.load();
    await categoryState.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceStateProvider.overrideWith((ref) => balanceState),
          accountStateProvider.overrideWith((ref) => accountState),
          categoryStateProvider.overrideWith((ref) => categoryState),
          transactionStateProvider.overrideWith((ref) => transactionState),
        ],
        child: const MaterialApp(home: TransactionsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(txnRepo.fetchAccountIds, contains(42));
    txnRepo.fetchAccountIds.clear();

    await tester.tap(find.byIcon(Icons.cancel).first);
    await tester.pumpAndSettle();

    expect(txnRepo.fetchAccountIds, contains(null));
  });
}

class _RecordingTransactionRepository extends TransactionRepository {
  final List<int?> fetchAccountIds = [];

  @override
  Future<List<SlothTransaction>> fetchPage({
    required int limit,
    required int offset,
    int? accountId,
    String? category,
    String? searchQuery,
  }) async {
    fetchAccountIds.add(accountId);
    return const [];
  }
}

class _StaticAccountRepository extends AccountRepository {
  _StaticAccountRepository(this._accounts);

  final List<SlothAccount> _accounts;

  @override
  Future<List<SlothAccount>> fetchAll() async => _accounts;
}

class _StaticCategoryRepository extends CategoryRepository {
  _StaticCategoryRepository(this._categories);

  final List<String> _categories;

  @override
  Future<List<String>> fetchAll() async => _categories;
}

class _EmptyBalanceRepository extends BalanceRepository {
  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async {
    return const [];
  }
}
