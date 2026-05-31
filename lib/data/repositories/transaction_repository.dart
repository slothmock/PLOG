import 'package:uuid/uuid.dart';

import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/data/db/db_service.dart';

class TransactionRepository {
  TransactionRepository({DBService? db}) : _db = db ?? DBService();

  final DBService _db;

  Future<List<SlothTransaction>> fetchAll({int? limit}) async {
    try {
      log.d('TransactionRepository.fetchAll(limit=$limit)');
      return await _db.getTransactions(limit: limit);
    } catch (e, st) {
      log.e(
        'TransactionRepository.fetchAll() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<SlothTransaction>> fetchPage({
    required int limit,
    required int offset,
    int? accountId,
    String? category,
    String? searchQuery,
  }) async {
    return _db.getTransactionsPaged(
      limit: limit,
      offset: offset,
      accountId: accountId,
      category: category,
      searchQuery: searchQuery,
    );
  }

  Future<List<SlothTransaction>> fetchIncome({int? limit}) async {
    try {
      log.d('TransactionRepository.fetchIncome(limit=$limit)');
      return await _db.getIncome(limit: limit);
    } catch (e, st) {
      log.e(
        'TransactionRepository.fetchIncome() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<SlothTransaction>> fetchExpenses({int? limit}) async {
    try {
      log.d('TransactionRepository.fetchExpenses(limit=$limit)');
      return await _db.getExpenses(limit: limit);
    } catch (e, st) {
      log.e(
        'TransactionRepository.fetchExpenses() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> create({
    required double amount,
    required String category,
    String? notes,
    String? merchant,
    required int dateMillis,
    required int accountId,
  }) async {
    try {
      log.i('TransactionRepository.create()');
      await _db.insertTransaction(
        amount: amount,
        category: category,
        notes: notes,
        merchant: merchant,
        dateMillis: dateMillis,
        accountId: accountId,
      );
    } catch (e, st) {
      log.e(
        'TransactionRepository.create() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> update(int id, Map<String, dynamic> fields) async {
    try {
      log.i(
        'TransactionRepository.update(id=$id, fields=${fields.keys.toList()})',
      );
      await _db.updateTransaction(id, fields);
    } catch (e, st) {
      log.e(
        'TransactionRepository.update() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<int> delete(int id) async {
    try {
      log.w('TransactionRepository.delete(id=$id)');
      return await _db.deleteTransaction(id);
    } catch (e, st) {
      log.e(
        'TransactionRepository.delete() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    try {
      log.w('TransactionRepository.deleteAll()');
      await _db.deleteAllTransactions();
    } catch (e, st) {
      log.e(
        'TransactionRepository.deleteAll() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> restore(SlothTransaction txn) async {
    try {
      log.w('TransactionRepository.restore(id=${txn.id})');
      await _db.insertTransaction(
        amount: txn.amount,
        category: txn.category,
        notes: txn.notes,
        merchant: txn.merchant,
        dateMillis: txn.date.millisecondsSinceEpoch,
        accountId: txn.accountId,
        transferGroupId: txn.transferGroupId,
      );
    } catch (e, st) {
      log.e(
        'TransactionRepository.restore() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? notes,
    required int dateMillis,
  }) async {
    final transferId = const Uuid().v4();

    await _db.runInTransaction((txn) async {
      // debit
      await txn.insert('transactions', {
        'amount_minor': DBService.toMinorUnits(-amount),
        'category': 'Transfer',
        'notes': notes,
        'merchant': null,
        'date': dateMillis,
        'account_id': fromAccountId,
        'transfer_group_id': transferId,
      });

      // credit
      await txn.insert('transactions', {
        'amount_minor': DBService.toMinorUnits(amount),
        'category': 'Transfer',
        'notes': notes,
        'merchant': null,
        'date': dateMillis,
        'account_id': toAccountId,
        'transfer_group_id': transferId,
      });
    });
  }

  Future<List<SlothTransaction>> fetchByTransferGroupId(String gid) async {
    try {
      log.d('TransactionRepository.fetchByTransferGroupId(gid=$gid)');
      return await _db.getTransactionsByTransferGroupId(gid);
    } catch (e, st) {
      log.e(
        'TransactionRepository.fetchByTransferGroupId() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<int> deleteByTransferGroupId(String gid) async {
    try {
      log.w('TransactionRepository.deleteByTransferGroupId(gid=$gid)');
      return await _db.deleteTransactionsByTransferGroupId(gid);
    } catch (e, st) {
      log.e(
        'TransactionRepository.deleteByTransferGroupId() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }
}
