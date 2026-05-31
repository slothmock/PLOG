import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/widgets/bottom_nav_bar.dart';

void main() {
  testWidgets('bottom nav renders PLOG sections and reports taps', (
    tester,
  ) async {
    var tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavBar(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.list), findsOneWidget);
    expect(find.byIcon(Icons.account_balance), findsOneWidget);
    expect(find.byIcon(Icons.autorenew), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance));
    expect(tappedIndex, 2);
  });
}
