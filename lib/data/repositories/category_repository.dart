import 'package:sloth_ledger/app/logging/app_logger.dart';
import 'package:sloth_ledger/data/db/db_service.dart';

class CategoryRepository {
  CategoryRepository({DBService? db}) : _db = db ?? DBService();
  final DBService _db;

  Future<List<String>> fetchAll() async {
    try {
      log.d('CategoryRepository.fetchAll()');
      return await _db.getCategories();
    } catch (e, st) {
      log.e('CategoryRepository.fetchAll() failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> create(String name) => _db.insertCategory(name);

  Future<void> rename(String from, String to) => _db.renameCategory(from, to);

  Future<int> usageCount(String name) => _db.countTransactionsForCategory(name);

  Future<void> reorder(List<String> orderedNames) async {
    log.i('CategoryRepository.reorder(${orderedNames.length} categories)');
    await _db.updateCategoryOrder(orderedNames);
  }

  Future<void> delete(String name) => _db.deleteCategoryByName(name);
}
