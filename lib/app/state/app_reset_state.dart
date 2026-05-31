import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/app_reset_repository.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';
import 'package:sloth_ledger/app/state/category_state.dart';
import 'package:sloth_ledger/app/state/settings_state.dart';
import 'package:sloth_ledger/features/ledger/state/transaction_state.dart';
import 'package:sloth_ledger/features/subscriptions/subscriptions.dart';

class AppResetState extends ChangeNotifier {
  AppResetState(this._repo);

  final AppResetRepository _repo;

  AccountState? _accounts;
  TransactionState? _txns;
  CategoryState? _categories;
  SettingsState? _settings;
  BalanceState? _balances;
  SubscriptionState? _subs;

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get errorMessage => _error;

  void setDeps({
    required AccountState accounts,
    required TransactionState txns,
    required CategoryState categories,
    required SettingsState settings,
    required BalanceState balances,
    required SubscriptionState subs,
  }) {
    _accounts = accounts;
    _txns = txns;
    _categories = categories;
    _settings = settings;
    _balances = balances;
    _subs = subs;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> reset() async {
    if (_loading) return false;

    _error = null;
    _loading = true;
    notifyListeners();

    try {
      log.w('AppResetState.reset()');
      await _repo.resetApp();

      await Future.wait([
        _accounts!.load(force: true),
        _categories!.load(force: true),
        _settings!.load(force: true),
        _txns!.loadAll(force: true),
        _balances!.load(force: true),
        _subs!.load(force: true),
      ]);

      _loading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      log.e(
        'AppResetState.reset() failed',
        error: safeLogError(e),
        stackTrace: st,
      );
      _error = 'Reset failed.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
