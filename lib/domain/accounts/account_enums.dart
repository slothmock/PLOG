enum AccountCategory { asset, liability }

extension AccountCategoryX on AccountCategory {
  String get dbValue => name;

  String get label {
    switch (this) {
      case AccountCategory.asset:
        return 'Assets';
      case AccountCategory.liability:
        return 'Liabilities';
    }
  }

  static AccountCategory fromDb(String? value) {
    if (value == null || value == 'fiat') return AccountCategory.asset;
    return AccountCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => AccountCategory.asset,
    );
  }
}

enum AccountType {
  // Assets
  cash,
  bank,

  // Liabilities
  creditCard,
  loan,
  mortgage,
}

extension AccountTypeX on AccountType {
  String get dbValue => name;

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.loan:
        return 'Loan';
      case AccountType.mortgage:
        return 'Mortgage';
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
    case AccountCategory.asset:
      return const [AccountType.cash, AccountType.bank];
    case AccountCategory.liability:
      return const [
        AccountType.creditCard,
        AccountType.loan,
        AccountType.mortgage,
      ];
  }
}
