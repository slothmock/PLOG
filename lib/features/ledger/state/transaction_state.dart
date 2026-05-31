import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/state/balance_state.dart';

class DeleteTransactionResult {
  const DeleteTransactionResult({
    required this.deleted,
    required this.isTransfer,
    required this.deletedTransactions,
  });

  const DeleteTransactionResult.notDeleted()
    : deleted = false,
      isTransfer = false,
      deletedTransactions = const [];

  final bool deleted;
  final bool isTransfer;
  final List<SlothTransaction> deletedTransactions;

  String get undoMessage =>
      isTransfer ? 'Transfer deleted' : 'Transaction deleted';
}

class TransactionState extends ChangeNotifier {
  BalanceState _balances;
  TransactionState(this._repo, this._balances);

  final TransactionRepository _repo;

  // UI state
  bool _loading = false; // “initial load” or “load more”
  bool _allLoaded = false; // we have loaded at least one page
  bool _refreshingAll = false; // pull-to-refresh / manual refresh spinner
  bool _hasMore = true;

  String? _errorMessage;

  bool get loading => _loading;
  bool get allLoaded => _allLoaded;
  bool get refreshingAll => _refreshingAll;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  final List<SlothTransaction> _all = [];
  List<SlothTransaction> get all => List.unmodifiable(_all);

  List<SlothTransaction> recent({int limit = 10}) {
    if (_all.isEmpty) return const [];
    if (_all.length <= limit) return List.unmodifiable(_all);
    return _all.take(limit).toList();
  }

  int _pageSize = 50;
  int _offset = 0;
  int? _activeAccountId;
  String? _activeCategory;
  String? _activeSearchQuery;

  Future<void>? _inFlight;

  void clearError() => _setError(null);

  void setBalances(BalanceState balances) {
    _balances = balances;
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

  Future<void> loadAll({bool force = false, int pageSize = 50}) async {
    _pageSize = pageSize;

    if (!force && _allLoaded) return;
    if (!force && _inFlight != null) return _inFlight!;

    _setError(null);

    final isInitial = _all.isEmpty && !_allLoaded;

    if (isInitial) {
      _setLoading(true);
    } else {
      _refreshingAll = true;
      notifyListeners();
    }

    final f = () async {
      try {
        log.i('TransactionState.loadAll(force=$force, pageSize=$_pageSize)');

        _offset = 0;
        _hasMore = true;

        final page = await _repo.fetchPage(
          limit: _pageSize,
          offset: 0,
          accountId: _activeAccountId,
          category: _activeCategory,
          searchQuery: _activeSearchQuery,
        );

        _all
          ..clear()
          ..addAll(page);
        _offset = page.length;

        _allLoaded = true;
        _hasMore = page.length == _pageSize;
      } catch (e, st) {
        log.e('TransactionState.loadAll() failed', error: e, stackTrace: st);
        _setError('Failed to load transactions.');
      } finally {
        _refreshingAll = false;
        _setLoading(false);
        _inFlight = null;
        notifyListeners();
      }
    }();

    _inFlight = f;
    return f;
  }

  Future<void> loadFiltered({
    int? accountId,
    String? category,
    String? searchQuery,
    int pageSize = 50,
  }) async {
    _activeAccountId = accountId;
    _activeCategory = category;
    _activeSearchQuery = searchQuery?.trim().isEmpty == true
        ? null
        : searchQuery?.trim();
    _allLoaded = false;
    _inFlight = null;
    await loadAll(force: true, pageSize: pageSize);
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    if (!_allLoaded) {
      return loadAll(force: false, pageSize: _pageSize);
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i('TransactionState.loadMore(limit=$_pageSize, offset=$_offset)');

      final page = await _repo.fetchPage(
        limit: _pageSize,
        offset: _offset,
        accountId: _activeAccountId,
        category: _activeCategory,
        searchQuery: _activeSearchQuery,
      );

      _all.addAll(page);
      _offset += page.length;

      _hasMore = page.length == _pageSize;
    } catch (e, st) {
      log.e('TransactionState.loadMore() failed', error: e, stackTrace: st);
      _setError('Failed to load more transactions.');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> ensureMinLoaded(int minCount) async {
    if (!_allLoaded) {
      await loadAll(force: false, pageSize: _pageSize);
    }
    while (_all.length < minCount && _hasMore && !_loading) {
      await loadMore();
    }
  }

  Future<void> ensureAllLoaded() async {
    if (!_allLoaded) {
      await loadAll(force: false, pageSize: _pageSize);
    }
    while (_hasMore && !_loading) {
      await loadMore();
    }
  }

  Future<void> refreshAll() async {
    await loadAll(force: true, pageSize: _pageSize);
    await _balances.load(force: true);
  }

  Future<void> _afterMutation() async {
    await loadAll(force: true, pageSize: _pageSize);
    await _balances.load(force: true);
  }

  Future<bool> create({
    required double amount,
    required String category,
    String? notes,
    String? merchant,
    required int dateMillis,
    required int accountId,
  }) async {
    if (category.trim().isEmpty) {
      _setError('Category is required.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i(
        'TransactionState.create(amount=$amount, category="$category", accountId=$accountId)',
      );

      await _repo.create(
        amount: amount,
        category: category.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        merchant: merchant?.trim().isEmpty == true ? null : merchant?.trim(),
        dateMillis: dateMillis,
        accountId: accountId,
      );

      await _afterMutation();
      return true;
    } catch (e, st) {
      log.e('TransactionState.create() failed', error: e, stackTrace: st);
      _setError('Failed to add transaction.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> update({
    required int id,
    required double amount,
    required String category,
    String? notes,
    String? merchant,
    required int dateMillis,
    required int accountId,
  }) async {
    if (category.trim().isEmpty) {
      _setError('Category is required.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i('TransactionState.update(id=$id)');

      await _repo.update(id, {
        'amount': amount,
        'category': category.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'merchant': merchant?.trim().isEmpty == true ? null : merchant?.trim(),
        'date': dateMillis,
        'account_id': accountId,
      });

      await _afterMutation();
      return true;
    } catch (e, st) {
      log.e('TransactionState.update() failed', error: e, stackTrace: st);
      _setError('Failed to update transaction.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> delete(int id) async {
    _setError(null);
    _setLoading(true);

    try {
      log.w('TransactionState.delete(id=$id)');
      await _repo.delete(id);

      await _afterMutation();
      return true;
    } catch (e, st) {
      log.e('TransactionState.delete() failed', error: e, stackTrace: st);
      _setError('Failed to delete transaction.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAll() async {
    _setError(null);
    _setLoading(true);

    try {
      log.w('TransactionState.deleteAll()');
      await _repo.deleteAll();

      _all.clear();
      _offset = 0;
      _hasMore = true;
      _allLoaded = false;
      _inFlight = null;

      await _balances.load(force: true);
    } catch (e, st) {
      log.e('TransactionState.deleteAll() failed', error: e, stackTrace: st);
      _setError('Failed to delete transaction history.');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<DeleteTransactionResult> deleteForUndo(SlothTransaction txn) async {
    _setError(null);

    // optional safety: block re-entry
    if (_loading) return const DeleteTransactionResult.notDeleted();

    _setLoading(true);

    final gid = txn.transferGroupId;
    final isTransfer = gid != null && gid.isNotEmpty;

    List<SlothTransaction> deleted = const [];
    int rowsAffected = 0;

    try {
      if (isTransfer) {
        // capture for undo
        deleted = await _repo.fetchByTransferGroupId(gid);

        // delete both legs
        rowsAffected = await _repo.deleteByTransferGroupId(gid);
      } else {
        if (txn.id == null) {
          _setError('Cannot delete: missing transaction id.');
          return const DeleteTransactionResult.notDeleted();
        }

        deleted = [txn];
        rowsAffected = await _repo.delete(txn.id!);
      }
      if (rowsAffected <= 0) {
        _setError('Nothing was deleted (already removed).');
        return const DeleteTransactionResult.notDeleted();
      }

      await _afterMutation();

      return DeleteTransactionResult(
        deleted: true,
        isTransfer: isTransfer,
        deletedTransactions: List.unmodifiable(deleted),
      );
    } catch (e, st) {
      log.e(
        'TransactionState.deleteForUndo() failed',
        error: e,
        stackTrace: st,
      );
      _setError('Failed to delete transaction.');
      return const DeleteTransactionResult.notDeleted();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> restoreDeleted(DeleteTransactionResult result) async {
    if (!result.deleted || result.deletedTransactions.isEmpty) return;

    _setError(null);
    _setLoading(true);

    try {
      // restore only what we actually deleted
      for (final t in result.deletedTransactions) {
        await _repo.restore(t);
      }
      await _afterMutation();
    } catch (e, st) {
      log.e(
        'TransactionState.restoreDeleted() failed',
        error: e,
        stackTrace: st,
      );
      _setError('Failed to restore transaction.');
    } finally {
      _setLoading(false);
    }
  }

  List<SlothTransaction> allForAccount(int accountId) {
    return _all.where((t) => t.accountId == accountId).toList();
  }

  List<SlothTransaction> filteredAll({int? accountId, String? category}) {
    return _all.where((t) {
      if (accountId != null && t.accountId != accountId) return false;
      if (category != null && t.category != category) return false;
      return true;
    }).toList();
  }

  Future<bool> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? notes,
    required int dateMillis,
  }) async {
    if (fromAccountId == toAccountId) {
      _setError('Choose two different accounts.');
      return false;
    }
    if (amount <= 0) {
      _setError('Enter a valid amount.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      await _repo.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        dateMillis: dateMillis,
      );

      await _afterMutation();
      return true;
    } catch (e, st) {
      log.e('TransactionState.transfer() failed', error: e, stackTrace: st);
      _setError('Transfer failed.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> ensureCoversMonth(DateTime now) async {
    final from = DateTime(now.year, now.month, 1);

    if (!_allLoaded) {
      await loadAll(force: false, pageSize: _pageSize);
    }

    // Keep loading until we either:
    // have no more pages, or
    // the oldest loaded txn is older than the start of month
    while (_hasMore &&
        !_loading &&
        _all.isNotEmpty &&
        _all.last.date.isAfter(from)) {
      await loadMore();
    }
  }
}
