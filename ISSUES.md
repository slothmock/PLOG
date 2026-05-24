# PLOG Code Review Issues

Review date: 2026-05-24
Repo: `D:\sloth_ledger`

Scope:
- Full repo review on `main`.
- No uncommitted changes were present at review time.
- `flutter analyze` passed.
- `flutter test` failed because the current widget test is stale.

## Priority Fixes

### 1. High — Duplicate account creation can replace existing accounts

Files:
- `lib/data/db/db_service.dart`
- `lib/data/repositories/account_repository.dart`

Issue:
`insertAccount()` uses `ConflictAlgorithm.replace` on a table where account name is unique.

In SQLite, `REPLACE` deletes the existing row and inserts a new one. For accounts, that can break existing ledger relationships because transactions/subscriptions may still point to the old account ID.

Impact:
Potential orphaned finance records and silent data corruption.

Recommended fix:
Use `ConflictAlgorithm.abort`/default behaviour, catch duplicate-name errors, and show a friendly validation message such as “Account name already exists”.

---

### 2. High — Foreign keys are incomplete/not reliably enforced

Files:
- `lib/data/db/db_service.dart`

Issue:
The database open path does not enable SQLite foreign key enforcement via `PRAGMA foreign_keys = ON`.

Some relationships are also missing explicit FK constraints, including:
- `subscriptions.account_id -> accounts.id`
- `subscription_events.subscription_id -> subscriptions.id`

Impact:
Deletes, resets, account replacement, or subscription changes can leave orphaned records.

Recommended fix:
Add `onConfigure` to `openDatabase()`:

```dart
onConfigure: (db) async {
  await db.execute('PRAGMA foreign_keys = ON');
},
```

Then define explicit foreign keys and intentional `ON DELETE` policies.

---

### 3. High — App reset leaves subscription event history behind

Files:
- `lib/data/repositories/app_reset_repository.dart`
- `lib/data/db/db_service.dart`

Issue:
`AppResetRepository.resetApp()` deletes transactions, categories, settings, accounts, and subscriptions, but does not delete `subscription_events`.

Impact:
Privacy/data-retention bug. A user can reset the app but still have subscription event history left in the database.

Recommended fix:
Delete all user-owned tables inside one transaction, in dependency order:

1. `subscription_events`
2. `transactions`
3. `subscriptions`
4. `categories`
5. `settings`
6. `accounts`

Then reseed defaults.

Also consolidate duplicate reset paths so there is one trusted reset implementation.

---

### 4. High — Subscription paid duplicate protection is flawed

Files:
- `lib/data/db/db_service.dart`
- `lib/data/repositories/subscriptions_repository.dart`

Issue:
The unique index is on:

```sql
subscription_id, kind, due_date
```

But paid subscription events do not consistently store `due_date`. SQLite allows multiple `NULL` values in a unique index, so this does not reliably prevent duplicate paid events.

The duplicate check also searches by payment `date` around the due date window, which can miss early/late payments.

Impact:
The same subscription cycle can be marked paid more than once, creating duplicate ledger transactions.

Recommended fix:
For paid events, always store the cycle due date:

```dart
'due_date': due.millisecondsSinceEpoch,
```

Then check duplicates by `subscription_id`, `kind = paid`, and exact `due_date`.

---

### 5. Medium — Account detail totals use only loaded transaction cache

Files:
- `lib/features/ledger/screens/account_details_screen.dart`
- `lib/features/ledger/state/transaction_state.dart`

Issue:
Account detail totals and history are calculated from `txnState.allForAccount()`, which filters the currently loaded transaction state.

If only the first transaction page is loaded, account totals/history can be incomplete.

Impact:
Wrong account totals for accounts with more than one page of transactions.

Recommended fix:
Move account-specific totals/history to repository/database queries, or explicitly load all pages for that account before calculating totals.

---

### 6. Medium — Ledger search/filter only applies to loaded pages

Files:
- `lib/features/ledger/screens/transactions_screen.dart`
- `lib/features/ledger/state/transaction_state.dart`

Issue:
Search and filters operate on the loaded in-memory transaction list rather than querying the full database.

Impact:
A matching transaction on an unloaded page will not appear. The app can show a false “no results”.

Recommended fix:
Implement DB-backed search/filter with pagination.

---

### 7. Medium — Money is stored as `REAL`/`double`

Files:
- `lib/data/db/db_service.dart`
- `lib/data/repositories/balance_repository.dart`

Issue:
Financial values are stored as SQLite `REAL` and represented in Dart as `double`.

Impact:
Floating-point rounding drift can appear over time. This is especially risky for a finance ledger.

Recommended fix:
Store money as integer minor units, e.g. pence/cents:

- £12.34 -> `1234`

If crypto support is added later, use asset-specific precision metadata rather than generic `double`.

---

### 8. Medium — Release logging may expose private finance data

Files:
- `lib/app/logging/app_logger.dart`
- `lib/data/repositories/account_repository.dart`
- `lib/data/repositories/transaction_repository.dart`

Issue:
Logging appears globally configured and some logs include account names, amounts, balances/categories, or stack traces.

Impact:
Sensitive finance data could be exposed in logs, bug reports, or shared-device debugging.

Recommended fix:
Gate verbose logging behind debug mode and redact sensitive values.

Example direction:

```dart
if (kReleaseMode) {
  Logger.level = Level.off;
} else {
  Logger.level = Level.debug;
}
```

---

### 9. Medium — Reset state performs an unawaited destructive call

File:
- `lib/app/state/app_reset_state.dart`

Issue:
After `await _repo.resetApp();`, reset state calls:

```dart
_txns?.deleteAll();
```

without awaiting it, then immediately reloads state.

Impact:
Race condition and redundant destructive operation after reset.

Recommended fix:
Remove `_txns?.deleteAll();` and let the reset repository own the full reset process.

---

### 10. Low/Medium — Account transaction-existence check loads all transactions

File:
- `lib/data/repositories/account_repository.dart`

Issue:
`hasTransactions()` fetches all transactions and then checks in Dart.

Impact:
Inefficient as the ledger grows, and potentially wrong if transaction loading becomes paginated/limited.

Recommended fix:
Add a DB-level existence query:

```sql
SELECT EXISTS(
  SELECT 1 FROM transactions WHERE account_id = ? LIMIT 1
)
```

---

### 11. Low/Medium — Widget test is stale and failing

File:
- `test/widget_test.dart`

Issue:
The test is still the default counter app test. It pumps the current app incorrectly and expects counter UI that does not exist.

Impact:
`flutter test` fails, so the test suite cannot protect future changes.

Recommended fix:
Replace with app-specific tests, such as:

- app smoke test with correct `ProviderScope`/`MaterialApp`/`Directionality` setup
- reset deletes `subscription_events`
- duplicate account name does not replace existing account
- subscription paid event cannot duplicate the same due cycle
- transfer creates two balanced transaction legs
- account totals include transactions beyond first page

---

## Suggested Fix Order

1. Fix app reset so it deletes `subscription_events`.
2. Remove `ConflictAlgorithm.replace` from account creation.
3. Enable and define database foreign keys.
4. Fix subscription paid-cycle duplicate protection.
5. Replace the stale widget test and add DB/repository regression tests.
6. Move account totals and ledger search/filter to DB-backed queries.
7. Consider migrating money storage to integer minor units before the app accumulates real data.

## Notes

The overall architecture is promising: repositories, state classes, feature folders, and a clear local-only finance model. The biggest risks are not UI polish; they are database integrity, privacy reset behaviour, and test coverage around destructive/financial operations.
