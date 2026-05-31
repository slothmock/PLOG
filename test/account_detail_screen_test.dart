import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/screens/account_details_screen.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';
import 'package:sloth_ledger/features/ledger/state/transaction_state.dart';

void main() {
  testWidgets('account detail loads transaction history filtered by account', (
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
    final repo = _RecordingTransactionRepository();
    final balanceState = BalanceState(_EmptyBalanceRepository());
    final transactionState = TransactionState(repo, balanceState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceStateProvider.overrideWith((ref) => balanceState),
          transactionStateProvider.overrideWith((ref) => transactionState),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: account)),
      ),
    );
    await tester.pump();

    expect(repo.fetchAccountIds, contains(account.id));
    expect(repo.fetchAccountIds, isNot(contains(null)));
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

class _EmptyBalanceRepository extends BalanceRepository {
  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async {
    return const [];
  }
}
