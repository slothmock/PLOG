import 'package:sloth_ledger/domain/money/money.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';

class SlothAccount {
  final int? id;
  final String name;

  final AccountCategory category;
  final AccountType type;

  final String currency;
  final int openingBalanceMinor;
  final DateTime createdAt;

  SlothAccount({
    this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.currency,
    required double openingBalance,
    required this.createdAt,
  }) : openingBalanceMinor = MoneyMinor.fromDouble(openingBalance);

  SlothAccount.fromMinorUnits({
    this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.currency,
    required this.openingBalanceMinor,
    required this.createdAt,
  });

  double get openingBalance => MoneyMinor.toDouble(openingBalanceMinor);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.dbValue,
      'type': type.dbValue,
      'currency': currency,
      'opening_balance_minor': openingBalanceMinor,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SlothAccount.fromMap(Map<String, dynamic> map) {
    final openingBalanceMinor = map['opening_balance_minor'] != null
        ? (map['opening_balance_minor'] as num).toInt()
        : MoneyMinor.fromDouble(
            ((map['opening_balance'] ?? 0) as num).toDouble(),
          );

    return SlothAccount.fromMinorUnits(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: AccountCategoryX.fromDb(map['category'] as String?),
      type: AccountTypeX.fromDb(map['type'] as String?),
      currency: map['currency'] as String,
      openingBalanceMinor: openingBalanceMinor,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  String get categoryLabel => category.label;
  String get typeLabel => type.label;
}
