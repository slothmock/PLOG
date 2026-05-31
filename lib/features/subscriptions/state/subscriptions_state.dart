import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/subscriptions_repository.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';

class SubscriptionState extends ChangeNotifier {
  SubscriptionState(this._repo);

  final SubscriptionRepository _repo;

  bool _loading = false;
  String? _errorMessage;
  Future<void>? _inFlight;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  final List<SlothSubscription> _all = [];
  List<SlothSubscription> get all => List.unmodifiable(_all);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    if (_loading == v) return;
    _loading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    if (_errorMessage == msg) return;
    _errorMessage = msg;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (!force && _inFlight != null) return _inFlight!;
    _setError(null);

    final f = () async {
      _setLoading(true);
      try {
        log.i('SubscriptionState.load(force=$force)');
        final items = await _repo.fetchAll(activeOnly: false);

        _all
          ..clear()
          ..addAll(items);
        // Sort by next due date ascending
        _all.sort((a, b) => a.nextDue.compareTo(b.nextDue));
      } catch (e, st) {
        log.e(
          'SubscriptionState.load() failed',
          error: safeLogError(e),
          stackTrace: st,
        );
        _setError('Failed to load subscriptions.');
      } finally {
        _setLoading(false);
        _inFlight = null;
      }
    }();

    _inFlight = f;
    return f;
  }

  Future<bool> create({
    required String name,
    required double amount,
    required String currency,
    required String interval,
    required DateTime nextDue,
    required int accountId,
  }) async {
    if (name.trim().isEmpty) {
      _setError('Name is required.');
      return false;
    }
    if (amount <= 0) {
      _setError('Enter a valid amount.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      await _repo.create(
        name: name.trim(),
        amount: amount,
        currency: currency,
        interval: interval,
        nextDueMillis: nextDue.millisecondsSinceEpoch,
        accountId: accountId,
        isActive: true,
      );

      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.create() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to add subscription.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> update({
    required int id,
    String? name,
    double? amount,
    String? interval,
    DateTime? nextDue,
    int? accountId,
    bool? isActive,
  }) async {
    final patch = <String, Object?>{
      if (name != null) 'name': name.trim(),
      'amount': ?amount,
      'interval': ?interval,
      if (nextDue != null) 'next_due': nextDue.millisecondsSinceEpoch,
      'account_id': ?accountId,
      if (isActive != null) 'is_active': isActive ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    // only updated_at → nothing meaningful to change
    if (patch.length == 1) return true;

    if (name != null && name.trim().isEmpty) {
      _setError('Name is required.');
      return false;
    }
    if (amount != null && amount <= 0) {
      _setError('Enter a valid amount.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      await _repo.update(id, patch);
      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.update() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to update subscription.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> delete(int id) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.delete(id);

      // Optimistic remove from local list first to give snappier UI response
      _all.removeWhere((s) => s.id == id);
      notifyListeners();

      // Then re-sync for truth
      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.delete() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to delete subscription.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> markPaid({
    required SlothSubscription sub,
    DateTime? paidAt,
    double? amountOverride,
    String? notes,
    int? txnId,
  }) async {
    if (sub.id == null) {
      _setError('Subscription id missing.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      await _repo.markPaid(
        sub: sub,
        paidAt: paidAt,
        amountOverride: amountOverride,
        notes: notes,
        txnId: txnId,
      );

      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.markPaid() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to mark subscription as paid.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> skipOnce(SlothSubscription sub) async {
    _setError(null);
    _setLoading(true);
    try {
      await _repo.skipOnce(sub: sub);
      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.skipOnce() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to skip.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> snooze(SlothSubscription sub, {required int days}) async {
    _setError(null);
    _setLoading(true);
    try {
      await _repo.snooze(sub: sub, days: days);
      await load(force: true);
      return true;
    } catch (e, st) {
      log.e(
        'SubscriptionState.snooze() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to snooze.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
