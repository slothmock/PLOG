import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/category_repository.dart';

class CategoryState extends ChangeNotifier {
  CategoryState(this._repo);

  final CategoryRepository _repo;

  // --- Public, observable state ---
  bool _loading = false;
  String? _errorMessage;
  List<String> _categories = const [];

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  List<String> get categories => List.unmodifiable(_categories);

  bool get hasData => _categories.isNotEmpty;

  // Prevent duplicate overlapping loads
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

  // --- Core operations ---

  /// Load categories from persistence.
  /// Safe to call multiple times; de-dupes overlapping loads.
  Future<void> load({bool force = false}) async {
    if (!force && _inFlightLoad != null) return _inFlightLoad!;

    _setError(null);
    _setLoading(true);

    final future = () async {
      try {
        log.i('CategoryState.load(force=$force)');
        final result = await _repo.fetchAll();
        _categories = result;
      } catch (e, st) {
        log.e('CategoryState.load() failed', error: e, stackTrace: st);
        _setError('Failed to load categories.');
      } finally {
        _setLoading(false);
        _inFlightLoad = null;
        notifyListeners();
      }
    }();

    _inFlightLoad = future;
    return future;
  }

  Future<bool> add(String name) async {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      _setError('Category name is required.');
      return false;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i('CategoryState.add("$trimmed")');

      await _repo.create(trimmed);
      await load(force: true);

      return true;
    } catch (e, st) {
      log.e('CategoryState.add() failed', error: e, stackTrace: st);
      _setError('Failed to add category.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rename(String from, String to) async {
    final oldName = from.trim();
    final newName = to.trim();

    if (newName.isEmpty) {
      _setError('Category name is required.');
      return false;
    }

    if (oldName == newName) {
      _setError(null);
      return true;
    }

    _setError(null);
    _setLoading(true);

    try {
      log.i('CategoryState.rename("$oldName" -> "$newName")');

      await _repo.rename(oldName, newName);
      await load(force: true);

      return true;
    } catch (e, st) {
      log.e('CategoryState.rename() failed', error: e, stackTrace: st);
      _setError('Failed to rename category.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reorder(List<String> ordered) async {
    _setError(null);

    try {
      log.i('CategoryState.reorder(count=${ordered.length})');

      await _repo.reorder(ordered);
      _categories = List.unmodifiable(ordered);
      notifyListeners();

      return true;
    } catch (e, st) {
      log.e('CategoryState.reorder() failed', error: e, stackTrace: st);
      _setError('Failed to reorder categories.');
      return false;
    }
  }

  /// Returns a user-facing message if deletion is not allowed; otherwise null.
  Future<String?> deleteWithRules(String name) async {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 'Invalid category.';
    }

    _setError(null);
    _setLoading(true);

    try {
      log.w('CategoryState.deleteWithRules("$trimmed")');

      if (trimmed == 'Subscriptions') {
        return '"Subscriptions" category can\'t be deleted.';
      }

      final count = await _repo.usageCount(trimmed);

      if (count > 0) {
        return 'Cannot delete: category is used by $count transaction(s). Rename it or reassign those transactions first.';
      }

      await _repo.delete(trimmed);
      await load(force: true);

      return null;
    } catch (e, st) {
      log.e('CategoryState.deleteWithRules() failed', error: e, stackTrace: st);
      _setError('Failed to delete category.');
      return 'Failed to delete category.';
    } finally {
      _setLoading(false);
    }
  }

  /// Handy for pull-to-refresh / retry buttons.
  Future<void> refresh() => load(force: true);

  /// Clear transient error, e.g. after showing a Snackbar.
  void clearError() => _setError(null);
}