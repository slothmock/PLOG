import 'package:sloth_ledger/domain/money/money.dart';

class SlothTransaction {
  final int? id;
  final int amountMinor; // positive = income, negative = expense
  final String category;
  final DateTime date;
  final String? notes;
  final String? merchant;
  final int accountId;
  final String? transferGroupId;

  SlothTransaction({
    this.id,
    required double amount,
    required this.category,
    required this.date,
    required this.accountId,
    this.notes,
    this.merchant,
    this.transferGroupId,
  }) : amountMinor = MoneyMinor.fromDouble(amount);

  SlothTransaction.fromMinorUnits({
    this.id,
    required this.amountMinor,
    required this.category,
    required this.date,
    required this.accountId,
    this.notes,
    this.merchant,
    this.transferGroupId,
  });

  double get amount => MoneyMinor.toDouble(amountMinor);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount_minor': amountMinor,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'merchant': merchant,
      'account_id': accountId,
      'transfer_group_id': transferGroupId,
    };
  }

  factory SlothTransaction.fromMap(Map<String, dynamic> map) {
    final amountMinor = map['amount_minor'] != null
        ? (map['amount_minor'] as num).toInt()
        : MoneyMinor.fromDouble(((map['amount'] ?? 0) as num).toDouble());

    return SlothTransaction.fromMinorUnits(
      id: map['id'] as int?,
      amountMinor: amountMinor,
      category: map['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      notes: map['notes'] as String?,
      merchant: map['merchant'] as String?,
      accountId: map['account_id'] as int,
      transferGroupId: map['transfer_group_id'] as String?,
    );
  }

  bool get isExpense => amountMinor < 0;
  bool get isIncome => amountMinor >= 0;
  bool get isTransfer =>
      (transferGroupId != null && transferGroupId!.isNotEmpty);
}
