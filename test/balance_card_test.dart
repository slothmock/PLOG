import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/widgets/balance_card.dart';

void main() {
  testWidgets('balance card info button opens explanatory dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BalanceCard(
            label: 'Net Worth',
            amount: 123,
            currencySymbol: '£',
            helpTitle: 'Net Worth',
            helpTooltip: 'What is net worth?',
            helpLines: ['Assets minus liabilities.'],
          ),
        ),
      ),
    );

    expect(find.byTooltip('What is net worth?'), findsOneWidget);

    await tester.tap(find.byTooltip('What is net worth?'));
    await tester.pumpAndSettle();

    expect(find.text('Assets minus liabilities.'), findsOneWidget);
  });

  testWidgets('summary row does not overflow on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: BalanceCard(
                  label: 'Assets',
                  amount: 1200,
                  currencySymbol: '£',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              Expanded(
                child: BalanceCard(
                  label: 'Liabilities',
                  amount: 650,
                  currencySymbol: '£',
                  icon: Icons.credit_card_outlined,
                ),
              ),
              Expanded(
                child: BalanceCard(
                  label: 'Net Worth',
                  amount: 550,
                  currencySymbol: '£',
                  icon: Icons.trending_up,
                  helpTitle: 'Net Worth',
                  helpTooltip: 'What is net worth?',
                  helpLines: ['Assets minus liabilities.'],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final cards = find.byType(BalanceCard);
    expect(cards, findsNWidgets(3));

    final firstSize = tester.getSize(cards.at(0));
    final secondSize = tester.getSize(cards.at(1));
    final thirdSize = tester.getSize(cards.at(2));

    expect(secondSize.width, firstSize.width);
    expect(thirdSize.width, firstSize.width);
    expect(secondSize.height, firstSize.height);
    expect(thirdSize.height, firstSize.height);
  });
}
