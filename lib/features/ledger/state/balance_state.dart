import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/balance_repository.dart';

class BalanceState extends ChangeNotifier {
  BalanceState(this._repo);

  final BalanceRepository _repo;

  bool _loading = false;
  String? _errorMessage;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  // accountId -> balance
  Map<int, double> _accountBalances = const {};
  Map<int, double> get accountBalances => _accountBalances;

  // currencyCode -> (category -> total)
  Map<String, Map<AccountCategory, double>> _totalsByCurrency = const {};
  Map<String, Map<AccountCategory, double>> get totalsByCurrency =>
      _totalsByCurrency;

  Future<void>? _inFlight;

  double totalFor({
    required String currencyCode,
    required AccountCategory category,
  }) {
    return _totalsByCurrency[currencyCode]?[category] ?? 0.0;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (!force && _inFlight != null) return _inFlight!;

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final f = () async {
      try {
        log.i('BalanceState.load(force=$force)');

        final rows = await _repo.fetchAccountBalanceRows();

        final accountBalances = <int, double>{};
        final totalsByCurrency = <String, Map<AccountCategory, double>>{};

        for (final r in rows) {
          final id = (r['id'] as int?) ?? -1;
          if (id <= 0) continue;

          final currency = (r['currency'] as String?) ?? 'GBP';

          final category = AccountCategoryX.fromDb(r['category'] as String?);

          final opening = ((r['opening_balance'] ?? 0) as num).toDouble();
          final txnTotal = ((r['txn_total'] ?? 0) as num).toDouble();
          final balance = switch (category) {
            AccountCategory.asset => opening + txnTotal,
            AccountCategory.liability => opening - txnTotal,
          };

          accountBalances[id] = balance;

          final bucket = totalsByCurrency.putIfAbsent(
            currency,
            () => {AccountCategory.asset: 0.0, AccountCategory.liability: 0.0},
          );

          bucket[category] = (bucket[category] ?? 0.0) + balance;
        }

        _accountBalances = accountBalances;
        _totalsByCurrency = totalsByCurrency;
      } catch (e, st) {
        log.e(
          'BalanceState.load() failed',
          error: safeLogError(e),
          stackTrace: st,
        );
        _errorMessage = 'Failed to load balances.';
      } finally {
        _loading = false;
        _inFlight = null;
        notifyListeners();
      }
    }();

    _inFlight = f;
    return f;
  }
}
