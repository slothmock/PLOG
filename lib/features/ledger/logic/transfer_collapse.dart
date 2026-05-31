import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';

List<SlothTransaction> collapseTransfers(
  List<SlothTransaction> txns,
  AccountState accountState,
) {
  final byGid = <String, List<SlothTransaction>>{};
  final out = <SlothTransaction>[];

  for (final t in txns) {
    final gid = t.transferGroupId;
    if (gid == null || gid.isEmpty) {
      out.add(t);
      continue;
    }
    byGid.putIfAbsent(gid, () => []).add(t);
  }

  for (final group in byGid.values) {
    if (group.isEmpty) continue;

    // If we only have one side (corrupt/partial), show it as-is.
    if (group.length == 1) {
      out.add(group.first);
      continue;
    }

    group.sort((a, b) => a.amount.compareTo(b.amount)); // negative first

    final fromLeg = group.firstWhere(
      (t) => t.amount < 0,
      orElse: () => group.first,
    );

    final toLeg = group.firstWhere(
      (t) => t.amount > 0,
      orElse: () => group.last,
    );

    final fromName =
        accountState.byId(fromLeg.accountId)?.name ??
        'Account ${fromLeg.accountId}';
    final toName =
        accountState.byId(toLeg.accountId)?.name ??
        'Account ${toLeg.accountId}';

    // Prefer memo from fromLeg, fallback to toLeg.
    final memo = (fromLeg.notes?.trim().isNotEmpty == true)
        ? fromLeg.notes!.trim()
        : (toLeg.notes?.trim().isNotEmpty == true ? toLeg.notes!.trim() : null);

    out.add(
      SlothTransaction(
        id: fromLeg.id,
        amount: fromLeg.amount,
        category: 'Transfer',
        date: fromLeg.date,
        accountId: fromLeg.accountId,
        transferGroupId: fromLeg.transferGroupId,

        merchant: '$fromName → $toName',
        notes: memo,
      ),
    );
  }

  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}
