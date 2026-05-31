# PLOG v0.2.0

PLOG 0.2.0 is a sizeable cleanup and reliability release.

This version keeps the app focused on its core idea: a private, manual, local-only ledger for Android. It also tightens the data model, improves the account overview, refreshes the public README/screenshots, and lays better groundwork for future budgeting, investing, crypto, and export features.

## Highlights

- Added clearer Assets, Liabilities, and Net Worth separation
- Improved account screens so assets and liabilities are shown as distinct sections
- Strengthened SQLite data integrity with foreign keys, safer delete behaviour, and duplicate protection
- Migrated money storage to integer minor units to avoid floating point drift
- Improved subscription payment handling and ledger refresh behaviour
- Added a custom toast overlay host for cleaner undo/info/error messages
- Continued Riverpod migration and state-management cleanup
- Refactored transaction delete/undo flow so UI behaviour no longer lives inside transaction state
- Added and expanded tests around database integrity, balance cards, account UI, toast overlays, and transaction undo behaviour
- Refreshed README and screenshots for the public release page
- Updated Android branding, splash screen, and package/app metadata

## What's changed

### Accounts and balances

- Added explicit asset/liability account categorisation
- Updated the home balance cards to show Assets, Liabilities, and Net Worth
- Updated accounts UI to keep Assets and Liabilities visually separate
- Added helpful empty-state copy for liability accounts
- Improved account creation/editing behaviour and validation paths

### Ledger and transactions

- Improved transaction rows and detail modal handling
- Extracted shared transaction row helper logic
- Moved transaction delete/undo UI handling out of `TransactionState`
- Added undo support that handles both single transactions and transfer pairs
- Improved ledger filtering/search paths so results are backed by database queries rather than only the currently loaded page
- Fixed transaction list refresh after marking a subscription as paid

### Subscriptions

- Improved subscription interval handling
- Tightened duplicate paid-event protection by tracking the specific due cycle
- Improved subscription/ledger integration when marking payments as paid
- Refined subscription UI and empty states

### Data integrity and storage

- Enabled SQLite foreign key enforcement
- Added missing foreign keys and intentional delete policies
- Fixed reset behaviour so related subscription event history is also removed
- Avoided account replacement on duplicate account names
- Migrated money values away from `REAL`/`double` storage to integer minor units
- Added database integrity tests for the important edge cases

### UI and app polish

- Added app icon/splash assets
- Improved bottom navigation and screen layouts
- Added reusable info/help affordances
- Added a toast overlay host for consistent undo, info, and error messages
- Updated public README copy and screenshot stitch

### Development and architecture

- Continued migration from Provider-style wiring to Riverpod
- Split startup/bootstrap provider wiring out of `main.dart`
- Removed unused files and stale helper modules
- Reduced duplication in transaction row/delete handling
- Added targeted tests for the refactors

## Privacy note

PLOG remains local-only and manual by design.

- No bank connection
- No login
- No cloud sync
- No third-party finance API

Your balances are based only on the accounts, transactions, transfers, and subscriptions you enter yourself.

## Known caveats

PLOG is still early development software.

- Future versions may include database migrations and workflow changes
- Import/export and backup tooling are still planned, not complete
- Budgeting, investment tracking, crypto support, and FX support remain roadmap items
- Keep your own backup of any important financial information

## APK

Attach the Android release APK built from this version:

`build/app/outputs/flutter-apk/app-release.apk`

## Full changelog

Compare with the previous release:

https://github.com/slothmock/sloth_ledger/compare/v0.1.3...v0.2.0
