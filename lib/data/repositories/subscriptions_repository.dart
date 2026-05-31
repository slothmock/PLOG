import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/db/db_service.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';
import 'package:sloth_ledger/features/subscriptions/logic/interval_helper.dart';

class SubscriptionRepository {
  SubscriptionRepository({DBService? db}) : _db = db ?? DBService();
  final DBService _db;

  Future<List<SlothSubscription>> fetchAll({bool activeOnly = false}) async {
    try {
      final rows = await _db.getSubscriptions(activeOnly: activeOnly);
      return rows.map(SlothSubscription.fromMap).toList();
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.fetchAll() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<int> create({
    required String name,
    required double amount,
    required String currency,
    required String interval,
    required int nextDueMillis,
    required int accountId,
    bool isActive = true,
  }) async {
    try {
      return await _db.insertSubscription(
        name: name,
        amount: amount,
        currency: currency,
        interval: interval,
        nextDueMillis: nextDueMillis,
        accountId: accountId,
        isActive: isActive,
      );
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.create() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> update(int id, Map<String, Object?> patch) async {
    try {
      await _db.updateSubscription(id, patch);
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.update() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _db.deleteSubscription(id);
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.delete() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  // For future use when implementing "link to transaction" feature
  Future<void> markPaid({
    required SlothSubscription sub,
    DateTime? paidAt,
    double? amountOverride,
    String? notes,
    int? txnId,
  }) async {
    try {
      await markPaidAndCreateTxn(
        sub: sub,
        paidAt: paidAt,
        amountOverride: amountOverride,
        notes: notes,
      );
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.markPaid() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<int?> markPaidAndCreateTxn({
    required SlothSubscription sub,
    DateTime? paidAt,
    double? amountOverride,
    String? notes,

    /// Use for future "link to transaction".
    int? existingTxnId,
    String subscriptionsCategory = 'Subscriptions',
    bool force = false,
  }) async {
    if (sub.id == null) {
      throw StateError('Subscription must have an id to markPaid.');
    }

    final dt = paidAt ?? DateTime.now();
    final due = sub.nextDue;

    final next = addInterval(due, sub.interval, count: 1);

    final raw = amountOverride ?? sub.amount;
    final expenseAmount = raw <= 0 ? raw : -raw;
    final dueMillis = due.millisecondsSinceEpoch;

    try {
      final database = await _db.db;

      int? createdTxnId;

      await database.transaction((txn) async {
        int? existingEventId;
        if (!force) {
          final existing = await txn.query(
            'subscription_events',
            columns: ['id', 'txn_id', 'due_date'],
            where: 'subscription_id = ? AND kind = ? AND due_date = ?',
            whereArgs: [sub.id, 'paid', dueMillis],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            final existingTxnId = existing.single['txn_id'] as int?;
            if (existingTxnId != null) {
              createdTxnId = null;
              return;
            }
            existingEventId = existing.single['id'] as int;
          }
        }

        final txnId =
            existingTxnId ??
            await txn.insert('transactions', {
              'amount_minor': DBService.toMinorUnits(expenseAmount),
              'category': subscriptionsCategory,
              'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
              'merchant': sub.name.trim(),
              'date': dt.millisecondsSinceEpoch,
              'account_id': sub.accountId,
              'transfer_group_id': null,
            });

        createdTxnId = txnId;

        if (existingEventId != null) {
          await txn.update(
            'subscription_events',
            {
              'amount_minor': DBService.toMinorUnits(raw),
              'date': dt.millisecondsSinceEpoch,
              'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
              'txn_id': txnId,
            },
            where: 'id = ?',
            whereArgs: [existingEventId],
          );
          return;
        }

        await txn.insert('subscription_events', {
          'subscription_id': sub.id,
          'kind': 'paid',
          'amount_minor': DBService.toMinorUnits(raw),
          'date': dt.millisecondsSinceEpoch,
          'due_date': dueMillis,
          'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
          'txn_id': txnId,
        });

        await txn.update(
          'subscriptions',
          {
            'next_due': next.millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [sub.id],
        );
      });

      return createdTxnId;
    } catch (e, st) {
      log.e(
        'SubscriptionRepository.markPaidAndCreateTxn() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> skipOnce({
    required SlothSubscription sub,
    DateTime? at,
    String? notes,
  }) async {
    final dt = at ?? DateTime.now();
    final next = addInterval(sub.nextDue, sub.interval, count: 1);

    final database = await _db.db;
    await database.transaction((txn) async {
      await txn.insert('subscription_events', {
        'subscription_id': sub.id,
        'kind': 'skipped',
        'amount_minor': null,
        'date': dt.millisecondsSinceEpoch,
        'due_date': sub.nextDue.millisecondsSinceEpoch,
        'notes': notes,
        'txn_id': null,
      });

      await txn.update(
        'subscriptions',
        {'next_due': next.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [sub.id],
      );
    });
  }

  Future<void> snooze({
    required SlothSubscription sub,
    required int days,
    String? notes,
  }) async {
    final dt = DateTime.now();
    final next = sub.nextDue.add(Duration(days: days));

    final database = await _db.db;
    await database.transaction((txn) async {
      await txn.insert('subscription_events', {
        'subscription_id': sub.id,
        'kind': 'snoozed',
        'amount_minor': null,
        'date': dt.millisecondsSinceEpoch,
        'notes': notes ?? 'Snoozed $days days',
      });

      await txn.update(
        'subscriptions',
        {'next_due': next.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [sub.id],
      );
    });
  }
}
