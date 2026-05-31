import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/data/db/db_service.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';

class AccountRepository {
  AccountRepository({DBService? db}) : _db = db ?? DBService();

  final DBService _db;

  Future<List<SlothAccount>> fetchAll() async {
    try {
      log.d('AccountRepository.fetchAll()');
      final rows = await _db.getAccounts();
      return rows.map(SlothAccount.fromMap).toList();
    } catch (e, st) {
      log.e(
        'AccountRepository.fetchAll() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> create({
    required String name,
    required AccountCategory category,
    required AccountType type,
    required String currency,
    double openingBalance = 0.0,
    int? createdAtMillis,
  }) async {
    try {
      log.i('AccountRepository.create()');

      await _db.insertAccount(
        name: name,
        category: category.dbValue,
        type: type.dbValue,
        currency: currency,
        openingBalance: openingBalance,
        createdAtMillis:
            createdAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      log.e(
        'AccountRepository.create() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> update({
    required int id,
    required String name,
    required AccountCategory category,
    required AccountType type,
    required String currency,
    required double openingBalance,
  }) async {
    try {
      log.i('AccountRepository.update()');

      await _db.updateAccount(
        id: id,
        name: name,
        category: category.dbValue,
        type: type.dbValue,
        currency: currency,
        openingBalance: openingBalance,
      );
    } catch (e, st) {
      log.e(
        'AccountRepository.update() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    try {
      log.w('AccountRepository.delete(id=$id)');
      await _db.deleteAccount(id);
    } catch (e, st) {
      log.e(
        'AccountRepository.delete() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Business rule helper: can’t delete accounts that have transactions.
  Future<bool> hasTransactions(int accountId) async {
    try {
      log.d('AccountRepository.hasTransactions(accountId=$accountId)');
      return await _db.hasTransactionsForAccount(accountId);
    } catch (e, st) {
      log.e(
        'AccountRepository.hasTransactions() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Business rule helper: can’t delete accounts that have active subscriptions.
  Future<bool> hasActiveSubscriptions(int accountId) async {
    try {
      log.d('AccountRepository.hasActiveSubscriptions(accountId=$accountId)');
      final subs = await _db.getSubscriptions(activeOnly: true);
      final accountSubs = subs.map(SlothSubscription.fromMap).toList();
      return accountSubs.any((s) => s.accountId == accountId && s.isActive);
    } catch (e, st) {
      log.e(
        'AccountRepository.hasActiveSubscriptions() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }
}
