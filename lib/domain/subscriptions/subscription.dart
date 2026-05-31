import 'package:sloth_ledger/domain/money/money.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription_enums.dart';

class SlothSubscription {
  final int? id;
  final String name;
  final int amountMinor;
  final String currency;
  final SubscriptionInterval interval;
  final DateTime nextDue;
  final int accountId;
  final bool isActive;

  SlothSubscription({
    this.id,
    required this.name,
    required double amount,
    required this.currency,
    required this.interval,
    required this.nextDue,
    required this.accountId,
    required this.isActive,
  }) : amountMinor = MoneyMinor.fromDouble(amount);

  SlothSubscription.fromMinorUnits({
    this.id,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.interval,
    required this.nextDue,
    required this.accountId,
    required this.isActive,
  });

  double get amount => MoneyMinor.toDouble(amountMinor);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount_minor': amountMinor,
    'currency': currency,
    'interval': interval.dbValue,
    'next_due': nextDue.millisecondsSinceEpoch,
    'account_id': accountId,
    'is_active': isActive ? 1 : 0,
  };

  factory SlothSubscription.fromMap(Map<String, dynamic> m) {
    final amountMinor = m['amount_minor'] != null
        ? (m['amount_minor'] as num).toInt()
        : MoneyMinor.fromDouble(((m['amount'] ?? 0) as num).toDouble());

    return SlothSubscription.fromMinorUnits(
      id: m['id'] as int?,
      name: m['name'] as String,
      amountMinor: amountMinor,
      currency: (m['currency'] as String?) ?? 'GBP',
      interval: SubscriptionInterval.fromDb(m['interval'] as String?),
      nextDue: DateTime.fromMillisecondsSinceEpoch(m['next_due'] as int),
      accountId: (m['account_id'] as int?) ?? 0,
      isActive: ((m['is_active'] ?? 1) as int) == 1,
    );
  }
}
