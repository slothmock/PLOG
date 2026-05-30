import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/app_settings/app_settings.dart';
import 'package:sloth_ledger/domain/money/money.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';

class DBService {
  // Singleton
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<void> resetForTesting() async {
    await _db?.close();
    _db = null;
  }

  static const int schemaVersion = 3;

  static int toMinorUnits(double value) => MoneyMinor.fromDouble(value);
  static double fromMinorUnits(int value) => MoneyMinor.toDouble(value);
  int getDbVersion() => schemaVersion;

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sloth_ledger.db');

    return await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
        CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL,
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_minor INTEGER NOT NULL,
        category TEXT NOT NULL,
        notes TEXT,
        merchant TEXT,
        date INTEGER NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        transfer_group_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
        CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

    await _createSubscriptionsTable(db);
    await _createSubsEventsTable(db);

    // Seed defaults
    await db.insert('settings', {'key': 'currency_code', 'value': 'GBP'});
    await db.insert('settings', {'key': 'currency_symbol', 'value': '£'});

    await db.insert('accounts', {
      'name': 'Cash',
      'category': 'fiat',
      'type': 'cash',
      'currency': 'GBP',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    const defaultCategories = [
      'Salary',
      'Rent',
      'Utilities',
      'Groceries',
      'Investment',
      'Entertainment',
      'Travel',
      'Subscriptions',
    ];

    for (var i = 0; i < defaultCategories.length; i++) {
      await db.insert('categories', {
        'name': defaultCategories[i],
        'sort_order': i,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
  }

  Future<void> _migrateToV2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE subscriptions_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          interval TEXT NOT NULL,
          next_due INTEGER NOT NULL,
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await txn.execute('''
        INSERT INTO subscriptions_new (
          id, name, amount, currency, interval, next_due, account_id,
          is_active, created_at, updated_at
        )
        SELECT s.id, s.name, s.amount, s.currency, s.interval, s.next_due,
          s.account_id, s.is_active, s.created_at, s.updated_at
        FROM subscriptions s
        INNER JOIN accounts a ON a.id = s.account_id;
      ''');

      await txn.execute('''
        CREATE TABLE subscription_events_migrate (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subscription_id INTEGER NOT NULL,
          kind TEXT NOT NULL,
          amount REAL,
          date INTEGER NOT NULL,
          due_date INTEGER,
          notes TEXT,
          txn_id INTEGER
        );
      ''');

      await txn.execute('''
        INSERT INTO subscription_events_migrate (
          id, subscription_id, kind, amount, date, due_date, notes, txn_id
        )
        SELECT e.id, e.subscription_id, e.kind, e.amount, e.date,
          e.due_date, e.notes, e.txn_id
        FROM subscription_events e
        INNER JOIN subscriptions_new s ON s.id = e.subscription_id
        LEFT JOIN transactions t ON t.id = e.txn_id
        WHERE e.txn_id IS NULL OR t.id IS NOT NULL;
      ''');

      await txn.execute('DROP TABLE subscription_events;');
      await txn.execute('DROP TABLE subscriptions;');
      await txn.execute(
        'ALTER TABLE subscriptions_new RENAME TO subscriptions;',
      );

      await txn.execute('''
        CREATE TABLE subscription_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subscription_id INTEGER NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
          kind TEXT NOT NULL,
          amount REAL,
          date INTEGER NOT NULL,
          due_date INTEGER,
          notes TEXT,
          txn_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL
        );
      ''');

      await txn.execute('''
        INSERT INTO subscription_events (
          id, subscription_id, kind, amount, date, due_date, notes, txn_id
        )
        SELECT id, subscription_id, kind, amount, date, due_date, notes, txn_id
        FROM subscription_events_migrate;
      ''');

      await txn.execute('DROP TABLE subscription_events_migrate;');
    });

    await _createSubscriptionsTable(db);
    await _createSubsEventsTable(db);
  }

  Future<void> _migrateToV3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE subscription_events RENAME TO subscription_events_old;',
      );
      await txn.execute('ALTER TABLE transactions RENAME TO transactions_old;');
      await txn.execute(
        'ALTER TABLE subscriptions RENAME TO subscriptions_old;',
      );
      await txn.execute('ALTER TABLE accounts RENAME TO accounts_old;');

      await txn.execute('''
        CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          currency TEXT NOT NULL,
          opening_balance_minor INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount_minor INTEGER NOT NULL,
          category TEXT NOT NULL,
          notes TEXT,
          merchant TEXT,
          date INTEGER NOT NULL,
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
          transfer_group_id TEXT
        )
      ''');
      await txn.execute('''
        CREATE TABLE subscriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          currency TEXT NOT NULL,
          interval TEXT NOT NULL,
          next_due INTEGER NOT NULL,
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE subscription_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subscription_id INTEGER NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
          kind TEXT NOT NULL,
          amount_minor INTEGER,
          date INTEGER NOT NULL,
          due_date INTEGER,
          notes TEXT,
          txn_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL
        )
      ''');

      await txn.execute('''
        INSERT INTO accounts (id, name, category, type, currency, opening_balance_minor, created_at)
        SELECT id, name, category, type, currency, ROUND(opening_balance * 100), created_at
        FROM accounts_old;
      ''');
      await txn.execute('''
        INSERT INTO transactions (id, amount_minor, category, notes, merchant, date, account_id, transfer_group_id)
        SELECT id, ROUND(amount * 100), category, notes, merchant, date, account_id, transfer_group_id
        FROM transactions_old;
      ''');
      await txn.execute('''
        INSERT INTO subscriptions (id, name, amount_minor, currency, interval, next_due, account_id, is_active, created_at, updated_at)
        SELECT id, name, ROUND(amount * 100), currency, interval, next_due, account_id, is_active, created_at, updated_at
        FROM subscriptions_old;
      ''');
      await txn.execute('''
        INSERT INTO subscription_events (id, subscription_id, kind, amount_minor, date, due_date, notes, txn_id)
        SELECT id, subscription_id, kind, CASE WHEN amount IS NULL THEN NULL ELSE ROUND(amount * 100) END,
          date, due_date, notes, txn_id
        FROM subscription_events_old;
      ''');

      await txn.execute('DROP TABLE subscription_events_old;');
      await txn.execute('DROP TABLE transactions_old;');
      await txn.execute('DROP TABLE subscriptions_old;');
      await txn.execute('DROP TABLE accounts_old;');
    });

    await _createSubscriptionsTable(db);
    await _createSubsEventsTable(db);
  }

  Future<void> _createSubscriptionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        interval TEXT NOT NULL,
        next_due INTEGER NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_next_due ON subscriptions(next_due);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON subscriptions(is_active);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_account ON subscriptions(account_id);',
    );
  }

  Future<void> _createSubsEventsTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS subscription_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subscription_id INTEGER NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      amount_minor INTEGER,
      date INTEGER NOT NULL,
      due_date INTEGER,
      notes TEXT,
      txn_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL
    );
  ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_events_subscription_id
      ON subscription_events(subscription_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_events_date
      ON subscription_events(date);
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_subscription_paid_cycle
      ON subscription_events(subscription_id, kind, due_date);
    ''');
  }

  Map<String, Object?> _normaliseMoneyFields(Map<String, Object?> fields) {
    final updateFields = Map<String, Object?>.of(fields);
    final amount = updateFields.remove('amount');
    if (amount != null) {
      updateFields['amount_minor'] = toMinorUnits((amount as num).toDouble());
    }
    final openingBalance = updateFields.remove('opening_balance');
    if (openingBalance != null) {
      updateFields['opening_balance_minor'] = toMinorUnits(
        (openingBalance as num).toDouble(),
      );
    }
    return updateFields;
  }

  Future<void> runInTransaction(
    Future<void> Function(Transaction txn) action,
  ) async {
    final database = await db;
    await database.transaction(action);
  }

  // =========================
  // ACCOUNTS
  // =========================

  Future<int> insertAccount({
    required String name,
    required String category,
    required String type,
    required String currency,
    required int createdAtMillis,
    double openingBalance = 0,
  }) async {
    final database = await db;
    return database.insert('accounts', {
      'name': name,
      'category': category,
      'type': type,
      'currency': currency,
      'opening_balance_minor': toMinorUnits(openingBalance),
      'created_at': createdAtMillis,
    });
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String category,
    required String type,
    required String currency,
    required double openingBalance,
  }) async {
    final database = await db;
    await database.update(
      'accounts',
      {
        'name': name,
        'category': category,
        'type': type,
        'currency': currency,
        'opening_balance_minor': toMinorUnits(openingBalance),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final database = await db;
    return database.query(
      'accounts',
      columns: [
        'id',
        'name',
        'category',
        'type',
        'currency',
        'opening_balance_minor',
        'created_at',
      ],
      orderBy: 'name',
    );
  }

  Future<int> deleteAccount(int id) async {
    final database = await db;
    return await database.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // =========================
  // TRANSACTIONS
  // =========================

  Future<int> insertTransaction({
    required double amount,
    required String category,
    String? notes,
    String? merchant,
    required int dateMillis,
    required int accountId,
    String? transferGroupId,
  }) async {
    final database = await db;
    return await database.insert('transactions', {
      'amount_minor': toMinorUnits(amount),
      'category': category,
      'notes': notes,
      'merchant': merchant,
      'date': dateMillis,
      'account_id': accountId,
      'transfer_group_id': transferGroupId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SlothTransaction>> getTransactions({int? limit}) async {
    final database = await db;
    final result = await database.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );

    return result.map((row) => SlothTransaction.fromMap(row)).toList();
  }

  Future<List<SlothTransaction>> getTransactionsPaged({
    required int limit,
    required int offset,
    int? accountId,
    String? category,
    String? searchQuery,
  }) async {
    final database = await db;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (accountId != null) {
      whereParts.add('account_id = ?');
      whereArgs.add(accountId);
    }

    final trimmedCategory = category?.trim();
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      whereParts.add('category = ?');
      whereArgs.add(trimmedCategory);
    }

    final trimmedQuery = searchQuery?.trim().toLowerCase();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      final like = '%$trimmedQuery%';
      final matchingAccountRows = await database.query(
        'accounts',
        columns: ['id'],
        where: 'LOWER(name) LIKE ?',
        whereArgs: [like],
      );
      final matchingAccountIds = matchingAccountRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      final searchParts = <String>[
        'LOWER(category) LIKE ?',
        "LOWER(COALESCE(merchant, '')) LIKE ?",
        "LOWER(COALESCE(notes, '')) LIKE ?",
        'CAST(amount_minor AS TEXT) LIKE ?',
        "printf('%.2f', amount_minor / 100.0) LIKE ?",
        "printf('%.2f', ABS(amount_minor) / 100.0) LIKE ?",
      ];
      final searchArgs = <Object?>[like, like, like, like, like, like];

      if (matchingAccountIds.isNotEmpty) {
        searchParts.add(
          'account_id IN (${List.filled(matchingAccountIds.length, '?').join(', ')})',
        );
        searchArgs.addAll(matchingAccountIds);
      }

      whereParts.add('(${searchParts.join(' OR ')})');
      whereArgs.addAll(searchArgs);
    }

    final result = await database.query(
      'transactions',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((row) => SlothTransaction.fromMap(row)).toList();
  }

  Future<List<SlothTransaction>> getExpenses({int? limit}) async {
    final database = await db;
    final result = await database.query(
      'transactions',
      where: 'amount_minor < 0',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((row) => SlothTransaction.fromMap(row)).toList();
  }

  Future<List<SlothTransaction>> getIncome({int? limit}) async {
    final database = await db;
    final result = await database.query(
      'transactions',
      where: 'amount_minor >= 0',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((row) => SlothTransaction.fromMap(row)).toList();
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> fields) async {
    final database = await db;
    final updateFields = _normaliseMoneyFields(fields);
    return await database.update(
      'transactions',
      updateFields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final database = await db;
    return await database.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> getTransactionAmounts() async {
    final database = await db;
    return database.query(
      'transactions',
      columns: ['account_id', 'amount_minor'],
    );
  }

  Future<bool> hasTransactionsForAccount(int accountId) async {
    final database = await db;
    final result = await database.query(
      'transactions',
      columns: ['id'],
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // =========================
  // CATEGORIES
  // =========================

  Future<int> insertCategory(String name) async {
    final database = await db;
    return await database.insert('categories', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<String>> getCategories() async {
    final database = await db;
    final result = await database.query(
      'categories',
      orderBy: 'sort_order ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  Future<int> countTransactionsForCategory(String name) async {
    final database = await db;
    final result = await database.query(
      'transactions',
      columns: ['id'],
      where: 'category = ?',
      whereArgs: [name],
    );
    return result.length;
  }

  Future<void> renameCategory(String from, String to) async {
    final database = await db;

    await database.transaction((txn) async {
      // Update categories table
      await txn.update(
        'categories',
        {'name': to},
        where: 'name = ?',
        whereArgs: [from],
      );

      // Update all transactions that reference the old category string
      await txn.update(
        'transactions',
        {'category': to},
        where: 'category = ?',
        whereArgs: [from],
      );
    });
  }

  Future<void> updateCategoryOrder(List<String> orderedNames) async {
    final database = await db;
    final batch = database.batch();

    for (var i = 0; i < orderedNames.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i},
        where: 'name = ?',
        whereArgs: [orderedNames[i]],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<int> deleteCategoryByName(String name) async {
    final database = await db;
    return database.delete('categories', where: 'name = ?', whereArgs: [name]);
  }

  // =========================
  // TRANSFER HELPERS
  // =========================

  Future<List<SlothTransaction>> getTransactionsByTransferGroupId(
    String transferGroupId,
  ) async {
    final database = await db;

    final rows = await database.query(
      'transactions',
      where: 'transfer_group_id = ?',
      whereArgs: [transferGroupId],
      orderBy: 'date DESC',
    );

    return rows.map((r) => SlothTransaction.fromMap(r)).toList();
  }

  Future<int> deleteTransactionsByTransferGroupId(
    String transferGroupId,
  ) async {
    final database = await db;

    return database.delete(
      'transactions',
      where: 'transfer_group_id = ?',
      whereArgs: [transferGroupId],
    );
  }

  // =========================
  // SUBSCRIPTIONS
  // =========================

  Future<int> insertSubscription({
    required String name,
    required double amount,
    required String currency,
    required String interval,
    required int nextDueMillis,
    required int accountId,
    bool isActive = true,
  }) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return database.insert('subscriptions', {
      'name': name,
      'amount_minor': toMinorUnits(amount),
      'currency': currency,
      'interval': interval,
      'next_due': nextDueMillis,
      'account_id': accountId,
      'is_active': isActive ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> getSubscriptions({
    bool activeOnly = true,
  }) async {
    final database = await db;

    return database.query(
      'subscriptions',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'next_due ASC, name COLLATE NOCASE ASC',
    );
  }

  Future<List<Map<String, Object?>>> getUpcomingSubscriptions({
    required int fromMillis,
    required int toMillis,
    bool activeOnly = true,
  }) async {
    final database = await db;

    final where = <String>[
      'next_due >= ?',
      'next_due <= ?',
      if (activeOnly) 'is_active = 1',
    ].join(' AND ');

    final args = [fromMillis, toMillis];

    return database.query(
      'subscriptions',
      where: where,
      whereArgs: args,
      orderBy: 'next_due ASC',
    );
  }

  Future<int> updateSubscription(int id, Map<String, Object?> fields) async {
    final database = await db;
    final updateFields = _normaliseMoneyFields(fields);
    updateFields['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    return database.update(
      'subscriptions',
      updateFields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubscription(int id) async {
    final database = await db;
    return database.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> setSubscriptionActive(int id, bool active) async {
    return updateSubscription(id, {'is_active': active ? 1 : 0});
  }

  // =========================
  // SETTINGS
  // =========================

  Future<String?> getSetting(String key) async {
    final database = await db;
    final result = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppSettings> getAppSettings() async {
    final code = await getSetting('currency_code');
    final symbol = await getSetting('currency_symbol');

    return AppSettings(
      currencyCode: code ?? AppSettings.defaults.currencyCode,
      currencySymbol: symbol ?? AppSettings.defaults.currencySymbol,
    );
  }

  Future<void> setCurrency({
    required String code,
    required String symbol,
  }) async {
    await setSetting('currency_code', code);
    await setSetting('currency_symbol', symbol);
  }

  Future<void> deleteAllTransactions() async {
    final database = await db;
    await database.delete('transactions');
  }

  Future<void> resetApp() async {
    final database = await db;

    await database.transaction((txn) async {
      await txn.delete('subscription_events');
      await txn.delete('transactions');
      await txn.delete('subscriptions');
      await txn.delete('categories');
      await txn.delete('settings');
      await txn.delete('accounts');

      await txn.insert('settings', {'key': 'currency_code', 'value': 'GBP'});
      await txn.insert('settings', {'key': 'currency_symbol', 'value': '£'});

      await txn.insert('accounts', {
        'name': 'Cash',
        'category': AccountCategory.fiat.dbValue,
        'type': AccountType.cash.dbValue,
        'currency': 'GBP',
        'opening_balance_minor': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      const defaultCategories = [
        'Salary',
        'Rent',
        'Utilities',
        'Groceries',
        'Investment',
        'Entertainment',
        'Travel',
        'Subscriptions',
      ];
      for (var i = 0; i < defaultCategories.length; i++) {
        await txn.insert('categories', {
          'name': defaultCategories[i],
          'sort_order': i,
        });
      }
    });
  }
}
