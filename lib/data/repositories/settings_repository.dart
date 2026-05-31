import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/domain/app_settings/app_settings.dart';
import 'package:sloth_ledger/data/db/db_service.dart';

class SettingsRepository {
  SettingsRepository({DBService? db}) : _db = db ?? DBService();
  final DBService _db;

  Future<AppSettings> fetchAppSettings() async {
    try {
      log.d('SettingsRepository.fetchAppSettings()');
      return await _db.getAppSettings();
    } catch (e, st) {
      log.e(
        'SettingsRepository.fetchAppSettings() failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> setCurrency({
    required String code,
    required String symbol,
  }) async {
    try {
      log.i('SettingsRepository.setCurrency(code=$code, symbol=$symbol)');
      await _db.setCurrency(code: code, symbol: symbol);
    } catch (e, st) {
      log.e(
        'SettingsRepository.setCurrency() failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
