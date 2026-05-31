import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/features/ledger/modals/transfer_modal.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

void main() {
  testWidgets('transfer modal allows asset to liability repayments', (
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
        SlothAccount(
          id: 2,
          name: 'Credit Card',
          category: AccountCategory.liability,
          type: AccountType.creditCard,
          currency: 'GBP',
          openingBalance: 250,
          createdAt: DateTime(2026),
        ),
      ]),
      balanceState,
    );
    await accountState.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceStateProvider.overrideWith((ref) => balanceState),
          accountStateProvider.overrideWith((ref) => accountState),
        ],
        child: const MaterialApp(home: Scaffold(body: TransferModal())),
      ),
    );

    expect(find.text('Transfer'), findsWidgets);
    expect(find.text('Credit Card'), findsOneWidget);
    expect(find.text('Same currency only'), findsOneWidget);
    expect(find.textContaining('same category'), findsNothing);
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
