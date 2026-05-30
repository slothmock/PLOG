import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/db/db_service.dart';

class BalanceRepository {
  BalanceRepository({DBService? db}) : _db = db ?? DBService();
  final DBService _db;

  Future<List<Map<String, Object?>>> fetchAccountBalanceRows() async {
    try {
      log.d('BalanceRepository.fetchAccountBalanceRows()');

      final accounts = await _db.getAccounts();
      final txnRows = await _db.getTransactionAmounts();

      // Sum amounts per account_id
      final totals = <int, double>{};
      for (final r in txnRows) {
        final id = (r['account_id'] as int);
        final amt = DBService.fromMinorUnits(
          (r['amount_minor'] as num).toInt(),
        );
        totals[id] = (totals[id] ?? 0.0) + amt;
      }

      // Re-shape accounts into "rows" with txn_total included
      final rows = <Map<String, Object?>>[];
      for (final a in accounts) {
        final id = (a['id'] as int?) ?? -1;
        if (id <= 0) continue;

        rows.add({
          'id': id,
          'name': a['name'],
          'category': a['category'],
          'type': a['type'],
          'currency': a['currency'],
          'opening_balance': DBService.fromMinorUnits(
            ((a['opening_balance_minor'] ?? 0) as num).toInt(),
          ),
          'txn_total': totals[id] ?? 0.0,
        });
      }

      rows.sort((x, y) {
        final a = (x['name'] as String? ?? '').toLowerCase();
        final b = (y['name'] as String? ?? '').toLowerCase();
        return a.compareTo(b);
      });

      log.d('BalanceRepository.fetchAccountBalanceRows(): ${rows.length} rows');
      return rows;
    } catch (e, st) {
      log.e(
        'BalanceRepository.fetchAccountBalanceRows() failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
