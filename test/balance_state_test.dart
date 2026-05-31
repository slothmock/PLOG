import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

void main() {
  test(
    'liability expenses increase amount owed and payments reduce it',
    () async {
      final state = BalanceState(
        _FakeBalanceRepository([
          {
            'id': 1,
            'name': 'Credit Card',
            'category': AccountCategory.liability.dbValue,
            'currency': 'GBP',
            'opening_balance': 100.0,
            // Expense/charge of 20 and payment/income of 5.
            'txn_total': -15.0,
          },
        ]),
      );

      await state.load();

      expect(state.accountBalances[1], 115.0);
      expect(
        state.totalFor(
          currencyCode: 'GBP',
          category: AccountCategory.liability,
        ),
        115.0,
      );
    },
  );

  test('asset balances keep normal income minus expense semantics', () async {
    final state = BalanceState(
      _FakeBalanceRepository([
        {
          'id': 2,
          'name': 'Bank',
          'category': AccountCategory.asset.dbValue,
          'currency': 'GBP',
          'opening_balance': 100.0,
          // Expense of 20 and income of 5.
          'txn_total': -15.0,
        },
      ]),
    );

    await state.load();

    expect(state.accountBalances[2], 85.0);
    expect(
      state.totalFor(currencyCode: 'GBP', category: AccountCategory.asset),
      85.0,
    );
  });
}

class _FakeBalanceRepository extends BalanceRepository {
  _FakeBalanceRepository(this.rows);

  final List<Map<String, Object?>> rows;

  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async => rows;
}
