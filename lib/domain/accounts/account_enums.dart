enum AccountCategory { fiat }

extension AccountCategoryX on AccountCategory {
  String get dbValue => name;

  String get label {
    switch (this) {
      case AccountCategory.fiat:
        return 'Fiat';
    }
  }

  static AccountCategory fromDb(String? value) {
    if (value == null) return AccountCategory.fiat;
    return AccountCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => AccountCategory.fiat,
    );
  }
}

enum AccountType {
  // Fiat
  cash,
  bank,
}

extension AccountTypeX on AccountType {
  String get dbValue => name;

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
    }
  }

  static AccountType fromDb(String? value) {
    if (value == null) return AccountType.cash;
    return AccountType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => AccountType.cash,
    );
  }
}

List<AccountType> accountTypesFor(AccountCategory category) {
  switch (category) {
    case AccountCategory.fiat:
      return const [AccountType.cash, AccountType.bank];
  }
}
