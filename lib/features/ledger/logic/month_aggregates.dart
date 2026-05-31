import 'package:sloth_ledger/domain/accounts/account_enums.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';

DateTime startOfMonth(DateTime now) => DateTime(now.year, now.month, 1);

double monthToDateNet({
  required List<SlothTransaction> txns,
  required AccountState accounts,
  required String currencyCode,
  DateTime? now,
  Set<AccountCategory> categories = const {AccountCategory.asset},
}) {
  final n = now ?? DateTime.now();
  final from = startOfMonth(n);

  double sum = 0;

  for (final t in txns) {
    if (t.date.isBefore(from)) continue;

    final acc = accounts.byId(t.accountId);
    if (acc == null) continue;

    if (acc.currency != currencyCode) continue;
    if (!categories.contains(acc.category)) continue;

    sum += t.amount;
  }

  return sum;
}
