import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sloth_ledger/data/db/db_service.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/app_reset_repository.dart';
import 'package:sloth_ledger/data/repositories/subscriptions_repository.dart';
import 'package:sloth_ledger/data/repositories/transaction_repository.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription_enums.dart';

void main() {
  late DBService db;
  late AppResetRepository resetRepo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await deleteDatabase(await _dbPath());
  });

  Future<void> resetForTest() async {
    await DBService.resetForTesting();
    await deleteDatabase(await _dbPath());
    db = DBService();
    resetRepo = AppResetRepository(db: db);
    await resetRepo.resetApp();
  }

  test('version 1 databases migrate to version 2 foreign-key schema', () async {
    final path = await _dbPath();
    await DBService.resetForTesting();
    await deleteDatabase(path);
    await _createVersion1Database(path);

    db = DBService();
    final database = await db.db;

    expect(await database.getVersion(), DBService.schemaVersion);
    expect(await _count(database, 'subscriptions'), 1);
    expect(await _count(database, 'subscription_events'), 1);

    expect(
      () => db.insertSubscription(
        name: 'Ghost Sub',
        amount: 9.99,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly.dbValue,
        nextDueMillis: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        accountId: 999999,
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'duplicate account names are rejected without replacing the original account',
    () async {
      await resetForTest();
      final accounts = AccountRepository(db: db);

      await accounts.create(
        name: 'Bills',
        category: AccountCategory.asset,
        type: AccountType.bank,
        currency: 'GBP',
        openingBalance: 10,
        createdAtMillis: 1,
      );

      expect(
        () => accounts.create(
          name: 'Bills',
          category: AccountCategory.asset,
          type: AccountType.bank,
          currency: 'GBP',
          openingBalance: 99,
          createdAtMillis: 2,
        ),
        throwsA(isA<DatabaseException>()),
      );

      final rows = await db.db.then(
        (database) =>
            database.query('accounts', where: 'name = ?', whereArgs: ['Bills']),
      );

      expect(rows, hasLength(1));
      expect(rows.single['opening_balance_minor'], 1000);
    },
  );

  test('foreign keys reject subscriptions for missing accounts', () async {
    await resetForTest();

    expect(
      () => db.insertSubscription(
        name: 'Ghost Sub',
        amount: 9.99,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly.dbValue,
        nextDueMillis: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        accountId: 999999,
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('money values are stored as integer minor units', () async {
    await resetForTest();
    final database = await db.db;
    final accounts = AccountRepository(db: db);

    await accounts.create(
      name: 'Bills',
      category: AccountCategory.asset,
      type: AccountType.bank,
      currency: 'GBP',
      openingBalance: 12.34,
      createdAtMillis: 1,
    );

    final billsId =
        (await database.query(
              'accounts',
              columns: ['id'],
              where: 'name = ?',
              whereArgs: ['Bills'],
              limit: 1,
            )).single['id']!
            as int;

    await db.insertTransaction(
      amount: -5.67,
      category: 'Groceries',
      dateMillis: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      accountId: billsId,
    );

    final subId = await db.insertSubscription(
      name: 'Gym',
      amount: 8.90,
      currency: 'GBP',
      interval: SubscriptionInterval.monthly.dbValue,
      nextDueMillis: DateTime(2026, 1, 31).millisecondsSinceEpoch,
      accountId: billsId,
    );

    await SubscriptionRepository(db: db).markPaidAndCreateTxn(
      sub: SlothSubscription(
        id: subId,
        name: 'Gym',
        amount: 8.90,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly,
        nextDue: DateTime(2026, 1, 31),
        accountId: billsId,
        isActive: true,
      ),
      paidAt: DateTime(2026, 1, 31),
    );

    final accountTypes = await _columnTypes(database, 'accounts');
    final transactionTypes = await _columnTypes(database, 'transactions');
    final subscriptionTypes = await _columnTypes(database, 'subscriptions');
    final eventTypes = await _columnTypes(database, 'subscription_events');

    expect(accountTypes['opening_balance_minor'], 'INTEGER');
    expect(transactionTypes['amount_minor'], 'INTEGER');
    expect(subscriptionTypes['amount_minor'], 'INTEGER');
    expect(eventTypes['amount_minor'], 'INTEGER');
    expect(accountTypes, isNot(contains('opening_balance')));
    expect(transactionTypes, isNot(contains('amount')));
    expect(subscriptionTypes, isNot(contains('amount')));
    expect(eventTypes, isNot(contains('amount')));

    final accountRow = (await database.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [billsId],
    )).single;
    expect(accountRow['opening_balance_minor'], 1234);

    final txnRows = await database.query(
      'transactions',
      columns: ['amount_minor', 'merchant'],
      orderBy: 'id ASC',
    );
    expect(
      txnRows.map((row) => row['amount_minor']),
      containsAll([-567, -890]),
    );

    final subRow = (await database.query(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [subId],
    )).single;
    expect(subRow['amount_minor'], 890);

    final eventRow = (await database.query('subscription_events')).single;
    expect(eventRow['amount_minor'], 890);
  });

  test('version 2 money values migrate to integer minor units', () async {
    final path = await _dbPath();
    await DBService.resetForTesting();
    await deleteDatabase(path);
    await _createVersion2Database(path);

    db = DBService();
    final database = await db.db;

    expect(await database.getVersion(), DBService.schemaVersion);

    final accountTypes = await _columnTypes(database, 'accounts');
    final transactionTypes = await _columnTypes(database, 'transactions');
    final subscriptionTypes = await _columnTypes(database, 'subscriptions');
    final eventTypes = await _columnTypes(database, 'subscription_events');

    expect(accountTypes['opening_balance_minor'], 'INTEGER');
    expect(transactionTypes['amount_minor'], 'INTEGER');
    expect(subscriptionTypes['amount_minor'], 'INTEGER');
    expect(eventTypes['amount_minor'], 'INTEGER');

    final account = (await database.query('accounts')).single;
    final txn = (await database.query('transactions')).single;
    final sub = (await database.query('subscriptions')).single;
    final event = (await database.query('subscription_events')).single;

    expect(account['opening_balance_minor'], 1234);
    expect(txn['amount_minor'], -567);
    expect(sub['amount_minor'], 890);
    expect(event['amount_minor'], 890);

    final txns = await TransactionRepository(db: db).fetchAll();
    final subs = await SubscriptionRepository(db: db).fetchAll();

    expect(txns.single.amount, -5.67);
    expect(subs.single.amount, 8.90);
  });

  test('app reset deletes subscription event history', () async {
    await resetForTest();
    final database = await db.db;
    final cashId =
        (await database.query(
              'accounts',
              columns: ['id'],
              where: 'name = ?',
              whereArgs: ['Cash'],
              limit: 1,
            )).single['id']!
            as int;

    final due = DateTime(2026, 1, 1);
    final subId = await db.insertSubscription(
      name: 'Gym',
      amount: 20,
      currency: 'GBP',
      interval: SubscriptionInterval.monthly.dbValue,
      nextDueMillis: due.millisecondsSinceEpoch,
      accountId: cashId,
    );

    await SubscriptionRepository(db: db).markPaidAndCreateTxn(
      sub: SlothSubscription(
        id: subId,
        name: 'Gym',
        amount: 20,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly,
        nextDue: due,
        accountId: cashId,
        isActive: true,
      ),
      paidAt: due,
    );

    expect(await _count(database, 'subscription_events'), 1);

    await resetRepo.resetApp();

    expect(await _count(database, 'subscription_events'), 0);
  });

  test(
    'paid subscription events store due date and cannot duplicate a cycle',
    () async {
      await resetForTest();
      final database = await db.db;
      final cashId =
          (await database.query(
                'accounts',
                columns: ['id'],
                where: 'name = ?',
                whereArgs: ['Cash'],
                limit: 1,
              )).single['id']!
              as int;

      final due = DateTime(2026, 1, 31);
      final subId = await db.insertSubscription(
        name: 'Streaming',
        amount: 12,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly.dbValue,
        nextDueMillis: due.millisecondsSinceEpoch,
        accountId: cashId,
      );
      final sub = SlothSubscription(
        id: subId,
        name: 'Streaming',
        amount: 12,
        currency: 'GBP',
        interval: SubscriptionInterval.monthly,
        nextDue: due,
        accountId: cashId,
        isActive: true,
      );
      final repo = SubscriptionRepository(db: db);

      final firstTxnId = await repo.markPaidAndCreateTxn(
        sub: sub,
        paidAt: DateTime(2026, 1, 1),
      );
      final duplicateTxnId = await repo.markPaidAndCreateTxn(
        sub: sub,
        paidAt: DateTime(2026, 1, 2),
      );

      expect(firstTxnId, isNotNull);
      expect(duplicateTxnId, isNull);

      final events = await database.query('subscription_events');
      expect(events, hasLength(1));
      expect(events.single['due_date'], due.millisecondsSinceEpoch);
    },
  );

  test('transaction search filters before paging', () async {
    await resetForTest();
    final database = await db.db;
    final cashId =
        (await database.query(
              'accounts',
              columns: ['id'],
              where: 'name = ?',
              whereArgs: ['Cash'],
              limit: 1,
            )).single['id']!
            as int;

    for (var i = 0; i < 30; i++) {
      await db.insertTransaction(
        amount: -1,
        category: 'Groceries',
        merchant: 'Filler $i',
        dateMillis: DateTime(2026, 2, i + 1).millisecondsSinceEpoch,
        accountId: cashId,
      );
    }

    await db.insertTransaction(
      amount: -12.50,
      category: 'Subscriptions',
      merchant: 'Needle Gym',
      notes: 'Should be found even though it is older than page one',
      dateMillis: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      accountId: cashId,
    );

    final results = await TransactionRepository(
      db: db,
    ).fetchPage(limit: 10, offset: 0, searchQuery: 'needle');

    expect(results, hasLength(1));
    expect(results.single.merchant, 'Needle Gym');
  });
}

Future<String> _dbPath() async {
  final dbPath = await getDatabasesPath();
  return '$dbPath/sloth_ledger.db';
}

Future<void> _createVersion1Database(String path) async {
  final database = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            category TEXT NOT NULL,
            type TEXT NOT NULL,
            currency TEXT NOT NULL,
            opening_balance REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            notes TEXT,
            merchant TEXT,
            date INTEGER NOT NULL,
            account_id INTEGER NOT NULL REFERENCES accounts(id),
            transfer_group_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            interval TEXT NOT NULL,
            next_due INTEGER NOT NULL,
            account_id INTEGER NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE subscription_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subscription_id INTEGER NOT NULL,
            kind TEXT NOT NULL,
            amount REAL,
            date INTEGER NOT NULL,
            due_date INTEGER,
            notes TEXT,
            txn_id INTEGER
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

        await db.insert('accounts', {
          'id': 1,
          'name': 'Cash',
          'category': 'fiat',
          'type': 'cash',
          'currency': 'GBP',
          'opening_balance': 0.0,
          'created_at': 1,
        });
        await db.insert('subscriptions', {
          'id': 1,
          'name': 'Gym',
          'amount': 20.0,
          'currency': 'GBP',
          'interval': SubscriptionInterval.monthly.dbValue,
          'next_due': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'account_id': 1,
          'is_active': 1,
          'created_at': 1,
          'updated_at': 1,
        });
        await db.insert('subscription_events', {
          'id': 1,
          'subscription_id': 1,
          'kind': 'paid',
          'amount': 20.0,
          'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'due_date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'notes': null,
          'txn_id': null,
        });
      },
    ),
  );
  await database.close();
}

Future<void> _createVersion2Database(String path) async {
  final database = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            category TEXT NOT NULL,
            type TEXT NOT NULL,
            currency TEXT NOT NULL,
            opening_balance REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            notes TEXT,
            merchant TEXT,
            date INTEGER NOT NULL,
            account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
            transfer_group_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE subscriptions (
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
          )
        ''');
        await db.execute('''
          CREATE TABLE subscription_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subscription_id INTEGER NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            amount REAL,
            date INTEGER NOT NULL,
            due_date INTEGER,
            notes TEXT,
            txn_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL
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

        await db.insert('accounts', {
          'id': 1,
          'name': 'Cash',
          'category': 'fiat',
          'type': 'cash',
          'currency': 'GBP',
          'opening_balance': 12.34,
          'created_at': 1,
        });
        await db.insert('transactions', {
          'id': 1,
          'amount': -5.67,
          'category': 'Groceries',
          'notes': null,
          'merchant': 'Shop',
          'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'account_id': 1,
          'transfer_group_id': null,
        });
        await db.insert('subscriptions', {
          'id': 1,
          'name': 'Gym',
          'amount': 8.90,
          'currency': 'GBP',
          'interval': SubscriptionInterval.monthly.dbValue,
          'next_due': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'account_id': 1,
          'is_active': 1,
          'created_at': 1,
          'updated_at': 1,
        });
        await db.insert('subscription_events', {
          'id': 1,
          'subscription_id': 1,
          'kind': 'paid',
          'amount': 8.90,
          'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'due_date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'notes': null,
          'txn_id': 1,
        });
      },
    ),
  );
  await database.close();
}

Future<Map<String, String>> _columnTypes(
  Database database,
  String table,
) async {
  final rows = await database.rawQuery('PRAGMA table_info($table)');
  return {
    for (final row in rows) row['name']! as String: row['type']! as String,
  };
}

Future<int> _count(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c']! as int?) ?? 0;
}
