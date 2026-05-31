import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/modals/transaction_detail_modal.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

void main() {
  testWidgets('transfer transactions do not offer unsafe single-leg editing', (
    tester,
  ) async {
    final balanceState = BalanceState(_EmptyBalanceRepository());
    final accountState = AccountState(
      _AccountRepository([
        SlothAccount(
          id: 1,
          name: 'Bank',
          category: AccountCategory.asset,
          type: AccountType.bank,
          currency: 'GBP',
          openingBalance: 1000,
          createdAt: DateTime(2026),
        ),
      ]),
      balanceState,
    );
    await accountState.load();

    final txn = SlothTransaction(
      id: 42,
      amount: -25,
      category: 'Transfer',
      date: DateTime(2026, 1, 2, 12),
      accountId: 1,
      transferGroupId: 'transfer-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceStateProvider.overrideWith((ref) => balanceState),
          accountStateProvider.overrideWith((ref) => accountState),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TransactionDetailModal(txn: txn, hostContext: context),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Transfer'), findsWidgets);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.textContaining('delete and recreate'), findsOneWidget);
  });
}

class _AccountRepository extends AccountRepository {
  _AccountRepository(this.accounts);

  final List<SlothAccount> accounts;

  @override
  Future<List<SlothAccount>> fetchAll() async => accounts;
}

class _EmptyBalanceRepository extends BalanceRepository {
  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async =>
      const [];
}
