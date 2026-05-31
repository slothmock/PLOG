import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';

void main() {
  group('AccountCategory', () {
    test('separates asset and liability buckets while reading legacy fiat as asset', () {
      expect(AccountCategory.asset.dbValue, 'asset');
      expect(AccountCategory.asset.label, 'Assets');
      expect(AccountCategory.liability.dbValue, 'liability');
      expect(AccountCategory.liability.label, 'Liabilities');
      expect(AccountCategoryX.fromDb('fiat'), AccountCategory.asset);
      expect(AccountCategoryX.fromDb('asset'), AccountCategory.asset);
      expect(AccountCategoryX.fromDb('liability'), AccountCategory.liability);
      expect(AccountCategoryX.fromDb(null), AccountCategory.asset);
    });
  });

  group('AccountType', () {
    test('offers cash and bank for assets, debt products for liabilities', () {
      expect(accountTypesFor(AccountCategory.asset), [AccountType.cash, AccountType.bank]);
      expect(accountTypesFor(AccountCategory.liability), [
        AccountType.creditCard,
        AccountType.loan,
        AccountType.mortgage,
      ]);
      expect(AccountType.creditCard.label, 'Credit Card');
      expect(AccountType.loan.label, 'Loan');
      expect(AccountType.mortgage.label, 'Mortgage');
    });
  });
}
