import 'package:flutter_test/flutter_test.dart';

import 'package:sloth_ledger/data/repositories/balance_repository.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';
import 'package:sloth_ledger/features/ledger/state/transaction_state.dart';

void main() {
  late _FakeTransactionRepository repo;
  late TransactionState state;

  setUp(() {
    repo = _FakeTransactionRepository([
      SlothTransaction(
        id: 1,
        amount: -5.67,
        category: 'Groceries',
        date: DateTime(2026, 1, 1),
        accountId: 1,
      ),
    ]);

    state = TransactionState(repo, BalanceState(_FakeBalanceRepository()));
  });

  test(
    'deleteForUndo deletes a transaction without needing BuildContext',
    () async {
      await state.loadAll(force: true);

      final result = await state.deleteForUndo(state.all.single);

      expect(result.deleted, isTrue);
      expect(result.undoMessage, 'Transaction deleted');
      expect(result.deletedTransactions, hasLength(1));
      expect(state.all, isEmpty);
    },
  );

  test(
    'restoreDeleted restores a transaction returned by deleteForUndo',
    () async {
      await state.loadAll(force: true);

      final result = await state.deleteForUndo(state.all.single);
      await state.restoreDeleted(result);

      expect(state.all, hasLength(1));
      expect(state.all.single.category, 'Groceries');
      expect(state.all.single.amount, -5.67);
    },
  );

  test('deleteForUndo on a transfer leg deletes both transfer legs', () async {
    repo.replaceAll(_transferPair());
    await state.loadAll(force: true);

    final result = await state.deleteForUndo(state.all.first);

    expect(result.deleted, isTrue);
    expect(result.undoMessage, 'Transfer deleted');
    expect(result.deletedTransactions, hasLength(2));
    expect(state.all, isEmpty);
  });

  test('restoreDeleted restores both deleted transfer legs', () async {
    repo.replaceAll(_transferPair());
    await state.loadAll(force: true);

    final result = await state.deleteForUndo(state.all.first);
    await state.restoreDeleted(result);

    expect(state.all, hasLength(2));
    expect(state.all.map((txn) => txn.amount).toList(), containsAll([-20, 20]));
    expect(state.all.map((txn) => txn.transferGroupId).toSet(), {'transfer-1'});
  });
}

List<SlothTransaction> _transferPair() {
  return [
    SlothTransaction(
      id: 10,
      amount: -20,
      category: 'Transfer',
      date: DateTime(2026, 1, 2),
      accountId: 1,
      transferGroupId: 'transfer-1',
    ),
    SlothTransaction(
      id: 11,
      amount: 20,
      category: 'Transfer',
      date: DateTime(2026, 1, 2),
      accountId: 2,
      transferGroupId: 'transfer-1',
    ),
  ];
}

class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository(this._transactions);

  final List<SlothTransaction> _transactions;

  void replaceAll(List<SlothTransaction> transactions) {
    _transactions
      ..clear()
      ..addAll(transactions);
  }

  @override
  Future<List<SlothTransaction>> fetchPage({
    required int limit,
    required int offset,
    int? accountId,
    String? category,
    String? searchQuery,
  }) async {
    return _transactions.skip(offset).take(limit).toList();
  }

  @override
  Future<int> delete(int id) async {
    final before = _transactions.length;
    _transactions.removeWhere((txn) => txn.id == id);
    return before - _transactions.length;
  }

  @override
  Future<void> restore(SlothTransaction txn) async {
    _transactions.add(txn);
  }

  @override
  Future<List<SlothTransaction>> fetchByTransferGroupId(String gid) async {
    return _transactions
        .where((txn) => txn.transferGroupId == gid)
        .toList(growable: false);
  }

  @override
  Future<int> deleteByTransferGroupId(String gid) async {
    final before = _transactions.length;
    _transactions.removeWhere((txn) => txn.transferGroupId == gid);
    return before - _transactions.length;
  }
}

class _FakeBalanceRepository extends BalanceRepository {
  @override
  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async {
    return const [];
  }
}
