import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sloth_ledger/data/db/db_service.dart';
import 'package:sloth_ledger/data/repositories/account_repository.dart';
import 'package:sloth_ledger/data/repositories/app_reset_repository.dart';
import 'package:sloth_ledger/data/repositories/subscriptions_repository.dart';
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
    db = DBService();
    resetRepo = AppResetRepository(db: db);
    await resetRepo.resetApp();
  }

  test('version 1 databases migrate to version 2 foreign-key schema', () async {
    final path = await _dbPath();
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
        category: AccountCategory.fiat,
        type: AccountType.bank,
        currency: 'GBP',
        openingBalance: 10,
        createdAtMillis: 1,
      );

      expect(
        () => accounts.create(
          name: 'Bills',
          category: AccountCategory.fiat,
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
      expect(rows.single['opening_balance'], 10.0);
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

Future<int> _count(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c']! as int?) ?? 0;
}
