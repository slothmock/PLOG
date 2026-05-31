import 'package:flutter/foundation.dart';
import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/repositories/settings_repository.dart';
import 'package:sloth_ledger/domain/app_settings/app_settings.dart';

class SettingsState extends ChangeNotifier {
  SettingsState(this._repo);

  final SettingsRepository _repo;

  bool _loading = false;
  String? _errorMessage;
  AppSettings _settings = AppSettings.defaults;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  AppSettings get settings => _settings;

  Future<void>? _inFlightLoad;

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

  void clearError() => _setError(null);

  Future<void> load({bool force = false}) async {
    if (!force && _inFlightLoad != null) return _inFlightLoad!;

    _setError(null);
    _setLoading(true);

    final f = () async {
      try {
        log.i('SettingsState.load(force=$force)');
        _settings = await _repo.fetchAppSettings();
      } catch (e, st) {
        log.e(
          'SettingsState.load() failed',
          error: safeLogError(e),
          stackTrace: st,
        );
        _setError('Failed to load settings.');
      } finally {
        _setLoading(false);
        _inFlightLoad = null;
        notifyListeners();
      }
    }();

    _inFlightLoad = f;
    return f;
  }
}
