# PLOG Code Review Issues

Review date: 2026-05-24
Repo: `D:\sloth_ledger`

Scope:
- Full repo review on `main`.
- No uncommitted changes were present at review time.
- `flutter analyze` passed at review time and still passes after the cleanup pass.
- `flutter test` failed at review time because the widget test was stale; this has since been fixed.

## Current Status

Last checked: 2026-05-30

Verification:
- `flutter analyze` passes.
- `flutter test` passes.
- `lib/data/db/db_service.dart` has no `rawQuery` usage.

Completed in this pass:
- Issues 1, 2, 3, 4, 6, 7, 9, 10, and 11 are complete.
- Issue 5 is resolved via explicit full-page loading for account detail totals/history.
- Issue 8 is resolved for release builds by disabling logger output in `kReleaseMode`; debug logs may still include values while developing.

Remaining:
- No known issue-tracker items remain open after this pass.

## Priority Fixes

### 1. High — Duplicate account creation can replace existing accounts

Status: **Done** — account creation now uses default/abort behaviour instead of `ConflictAlgorithm.replace`, preserving existing account rows on duplicate names.

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

Status: **Done** — `openDatabase()` enables `PRAGMA foreign_keys = ON`; subscription tables now define explicit foreign keys and delete policies.

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

Status: **Done** — reset deletes `subscription_events` first inside the reset transaction before reseeding defaults.

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

Status: **Done** — paid events store the cycle `due_date` and duplicate checks use `subscription_id`, `kind`, and exact `due_date`.

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

Status: **Done** — account detail explicitly calls `ensureAllLoaded()` before calculating account totals/history from transaction state.

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

Status: **Done** — ledger filters/search are DB-backed through paged transaction queries.

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

Status: **Done** — schema version 3 stores money columns as integer minor units and migrates version 2 `REAL` values with `ROUND(value * 100)`.

Files:
- `lib/data/db/db_service.dart`
- `lib/data/repositories/balance_repository.dart`
- `lib/data/repositories/transaction_repository.dart`
- `lib/data/repositories/subscriptions_repository.dart`
- `lib/domain/money/money.dart`
- `lib/domain/accounts/account.dart`
- `lib/domain/transactions/transaction.dart`
- `lib/domain/subscriptions/subscription.dart`
- `test/db_integrity_test.dart`

Issue:
Financial values are stored as SQLite `REAL` and represented in Dart as `double`.

Impact:
Floating-point rounding drift can appear over time. This is especially risky for a finance ledger.

Implemented fix:
Money is stored as integer minor units, e.g. pence/cents:

- £12.34 -> `1234`

The public UI-facing APIs still expose decimal `double` values where the app already expects them, but persistence and domain entities now keep canonical `*_minor` integers.

If crypto support is added later, use asset-specific precision metadata rather than generic `double`.

---

### 8. Medium — Release logging may expose private finance data

Status: **Done for release builds** — logger output is disabled in `kReleaseMode`; debug logs remain verbose for development.

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

Status: **Done** — `AppResetState.reset()` no longer calls the redundant unawaited transaction delete.

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

Status: **Done** — account transaction checks now use a DB-level limited query.

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

Status: **Done** — the stale counter test has been replaced and the test suite passes.

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

## Remaining Fix Order

No known issue-tracker items remain open.

## Notes

The overall architecture is promising: repositories, state classes, feature folders, and a clear local-only finance model. The biggest risks are not UI polish; they are database integrity, privacy reset behaviour, and test coverage around destructive/financial operations.
