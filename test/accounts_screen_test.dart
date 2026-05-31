import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/features/ledger/screens/accounts_screen.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

class _EmptyAccountRepository extends AccountRepository {
  @override
  Future<List<SlothAccount>> fetchAll() async => const [];
}

class _EmptyBalanceRepository extends BalanceRepository {
  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async => const [];
}

void main() {
  testWidgets('accounts screen shows asset and liability sections when empty', (
    tester,
  ) async {
    final balanceState = BalanceState(_EmptyBalanceRepository());
    final accountState = AccountState(_EmptyAccountRepository(), balanceState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceStateProvider.overrideWith((ref) => balanceState),
          accountStateProvider.overrideWith((ref) => accountState),
        ],
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );

    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Liabilities'), findsOneWidget);
    expect(find.text('No asset accounts yet'), findsOneWidget);
    expect(find.text('No liability accounts yet'), findsOneWidget);
    expect(
      find.text('Credit cards, loans, mortgages, and finance agreements appear here.'),
      findsOneWidget,
    );
    expect(find.byTooltip('What are liabilities?'), findsOneWidget);

    await tester.tap(find.byTooltip('What are liabilities?'));
    await tester.pumpAndSettle();

    expect(find.text('Money you owe.'), findsOneWidget);
    expect(
      find.text('Enter the amount owed as a positive number; PLOG subtracts it from net worth.'),
      findsOneWidget,
    );
  });
}
