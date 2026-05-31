# <img src="assets/splash.png" width="56" alt="PLOG app icon"> PLOG - A private manual ledger for Android

![GitHub release](https://img.shields.io/github/v/release/slothmock/sloth_ledger)
![GitHub downloads](https://img.shields.io/github/downloads/slothmock/sloth_ledger/total)
![License](https://img.shields.io/github/license/slothmock/sloth_ledger)
![Status](https://img.shields.io/badge/status-early%20development-orange)
![Platform](https://img.shields.io/badge/platform-Android-green)
![Privacy](https://img.shields.io/badge/data-local%20only-success)

PLOG is a simple, privacy-first ledger app for tracking money manually.

It is built for people who want a clear view of their accounts, spending, income, and subscriptions without connecting a bank account or sending financial data to a third party.

## What PLOG does

- Track cash, bank, savings, investment, crypto, and liability accounts
- Add income and expense transactions manually
- Transfer money between accounts that use the same currency
- Group transactions by day with daily totals
- Search and filter ledger history
- Track upcoming, paid, paused, due-soon, and overdue subscriptions
- Mark subscriptions as paid and create the matching ledger transaction
- Separate assets and liabilities for clearer net worth tracking
- Store money values as integer minor units to avoid floating point drift
- Keep all app data on the device

## Screenshots

<p align="center">
  <img src="assets/screenshots/ui stitch.png" width="100%" alt="PLOG app screenshots">
</p>

## Privacy

PLOG is intentionally manual and local-only.

- It does not connect to banks
- It does not require a login
- It does not upload your ledger to a server
- It does not rely on a third-party finance API

Your balances are only as complete as the transactions you enter, which is the point: the app is designed for deliberate, hands-on money tracking rather than automatic categorisation.

## Current status

PLOG is in early development and is primarily built around my own financial workflow.

That means:

- Features may change between releases
- Database migrations may be introduced as the app matures
- Some planned modules are not finished yet
- You should keep your own backup of important financial information

If you try a release, treat it as useful-but-young software rather than a polished finance product.

## Download

Android releases are available from the GitHub Releases page:

https://github.com/slothmock/sloth_ledger/releases

## Roadmap

Planned areas of development include:

- Stronger recurring/subscription workflows
- Budgeting tools
- Traditional investment tracking
- Crypto account support
- Foreign exchange support for multi-currency accounts
- Import/export or backup options
- More tests and continued architecture cleanup

## Development

PLOG is a Flutter app using a local SQLite database.

Core stack:

- Flutter
- Dart
- sqflite
- Riverpod

Useful commands:

```bash
flutter pub get
flutter analyze
flutter test
```

## AI-assisted development

This app is built with support from modern AI coding tools.

The code is still reviewed, tested, and shaped around a real personal use case, but AI assistance is part of the workflow. If that matters to you, please inspect the code before relying on it.

Thoughtful issues, refactors, and review comments are welcome.

## License

See [LICENSE](LICENSE).
