import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/domain/accounts/account.dart';

import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

class AccountState extends ChangeNotifier {
  BalanceState _balances;

  AccountState(this._repo, this._balances);

  final AccountRepository _repo;

  // --- Public, observable state ---
  bool _loading = false;
  String? _errorMessage;
  List<SlothAccount> _accounts = const [];

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  List<SlothAccount> get accounts => List.unmodifiable(_accounts);

  bool get hasData => _accounts.isNotEmpty;

  // Prevent duplicate overlapping loads (common in startup + hot reload + tab switching)
  Future<void>? _inFlightLoad;

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  void setBalances(BalanceState balances) {
    _balances = balances;
  }

  // --- Core operations ---

  /// Load accounts from persistence.
  /// Safe to call multiple times; de-dupes overlapping loads.
  Future<void> load({bool force = false}) async {
    if (!force && _inFlightLoad != null) return _inFlightLoad!;

    _setError(null);
    _setLoading(true);

    final future = () async {
      try {
        log.i('AccountState.load(force=$force)');
        final result = await _repo.fetchAll();
        _accounts = result;
      } catch (e, st) {
        log.e(
          'AccountState.load() failed',
          error: safeLogError(e),
          stackTrace: st,
        );
        _setError('Failed to load accounts.');
      } finally {
        _setLoading(false);
        _inFlightLoad = null;
        notifyListeners();
      }
    }();

    _inFlightLoad = future;
    return future;
  }

  /// Create account and refresh list.
  Future<bool> create({
    required String name,
    required AccountCategory category,
    required AccountType type,
    required String currency,
    required double openingBalance,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _setError('Account name is required.');
      return false;
    }
    if (openingBalance.isNaN || openingBalance.isInfinite) {
      _setError('Starting balance must be a valid number.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i(
        'AccountState.create(name="$trimmed", category=${category.dbValue}, type=${type.dbValue}, currency="$currency", openingBalance=$openingBalance)',
      );

      await _repo.create(
        name: trimmed,
        category: category,
        type: type,
        currency: currency,
        openingBalance: openingBalance,
      );

      await load(force: true);

      await _balances.load(force: true);

      return true;
    } catch (e, st) {
      log.e(
        'AccountState.create() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to add account.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> update({
    required int id,
    required String name,
    required AccountCategory category,
    required AccountType type,
    required String currency,
    required double openingBalance,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _setError('Account name is required.');
      return false;
    }
    if (openingBalance.isNaN || openingBalance.isInfinite) {
      _setError('Starting balance must be a valid number.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i(
        'AccountState.update(id=$id, name="$trimmed", category=${category.dbValue}, type=${type.dbValue}, currency="$currency", openingBalance=$openingBalance)',
      );

      await _repo.update(
        id: id,
        name: trimmed,
        category: category,
        type: type,
        currency: currency,
        openingBalance: openingBalance,
      );

      await load(force: true);

      await _balances.load(force: true);

      return true;
    } catch (e, st) {
      log.e(
        'AccountState.update() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to update account.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete with rules:
  /// - cannot delete last remaining account
  /// - cannot delete if any transactions exist for this account
  ///
  /// Returns a user-friendly message on failure (null on success).
  Future<String?> deleteWithRules(int accountId) async {
    _setError(null);
    _setLoading(true);

    try {
      log.w('AccountState.deleteWithRules(accountId=$accountId)');

      // Ensure we’re working with current data.
      if (_accounts.isEmpty) {
        await load(force: true);
      }

      if (_accounts.length <= 1) {
        _setLoading(false);
        return 'Cannot delete the last account.';
      }

      final hasTxns = await _repo.hasTransactions(accountId);
      final hasActiveSubs = await _repo.hasActiveSubscriptions(accountId);
      if (hasTxns) {
        _setLoading(false);
        return 'Cannot delete accounts with transactions.';
      }
      if (hasActiveSubs) {
        _setLoading(false);
        return 'Cannot delete accounts with active subscriptions.';
      }

      await _repo.delete(accountId);
      await load(force: true);
      await _balances.load(force: true);
      return null;
    } catch (e, st) {
      log.e(
        'AccountState.deleteWithRules() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _setError('Failed to delete account.');
      _setLoading(false);
      notifyListeners();
      return 'Failed to delete account.';
    }
  }

  SlothAccount? byId(int id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Handy for pull-to-refresh / retry buttons.
  Future<void> refresh() => load(force: true);

  /// Clear transient error (e.g. after showing a Snackbar).
  void clearError() => _setError(null);
}
