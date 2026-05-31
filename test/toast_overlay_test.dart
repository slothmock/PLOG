import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';
import 'package:sloth_ledger/app/widgets/undo_toast.dart';

void main() {
  Future<BuildContext> pumpNavigatorContext(WidgetTester tester) async {
    late BuildContext navigatorContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navigatorContext = Navigator.of(context).context;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );

    return navigatorContext;
  }

  testWidgets('UndoToast can show from a Navigator context', (tester) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = UndoToast.show(
      navigatorContext,
      message: 'Transaction deleted',
      duration: const Duration(milliseconds: 10),
    );

    await tester.pump();
    expect(find.text('Transaction deleted'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    expect(await future, isFalse);
  });

  testWidgets('UndoToast dismisses when tapping outside', (tester) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = UndoToast.show(
      navigatorContext,
      message: 'Tap away undo',
      duration: const Duration(seconds: 30),
    );

    await tester.pump();
    expect(find.text('Tap away undo'), findsOneWidget);

    await tester.tapAt(const Offset(400, 400));
    await tester.pump();

    expect(find.text('Tap away undo'), findsNothing);
    expect(await future, isFalse);
  });

  testWidgets('UndoToast returns true when undo action is tapped', (
    tester,
  ) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = UndoToast.show(
      navigatorContext,
      message: 'Undoable action',
      duration: const Duration(seconds: 30),
    );

    await tester.pump();
    expect(find.text('Undoable action'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pump();

    expect(find.text('Undoable action'), findsNothing);
    expect(await future, isTrue);
  });

  testWidgets('CustomInfoToast can show from a Navigator context', (
    tester,
  ) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = CustomInfoToast.show(
      navigatorContext,
      message: 'Saved',
      duration: const Duration(milliseconds: 10),
    );

    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await future;
  });

  testWidgets('CustomInfoToast dismisses when tapping outside', (tester) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = CustomInfoToast.show(
      navigatorContext,
      message: 'Tap away info',
      duration: const Duration(seconds: 30),
    );

    await tester.pump();
    expect(find.text('Tap away info'), findsOneWidget);

    await tester.tapAt(const Offset(400, 400));
    await tester.pump();

    expect(find.text('Tap away info'), findsNothing);
    await future;
  });

  testWidgets('ErrorToast can show from a Navigator context', (tester) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = ErrorToast.show(
      navigatorContext,
      message: 'Something went wrong',
      duration: const Duration(milliseconds: 10),
    );

    await tester.pump();
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await future;
  });

  testWidgets('ErrorToast dismisses when tapping outside', (tester) async {
    final navigatorContext = await pumpNavigatorContext(tester);

    final future = ErrorToast.show(
      navigatorContext,
      message: 'Tap away error',
      duration: const Duration(seconds: 30),
    );

    await tester.pump();
    expect(find.text('Tap away error'), findsOneWidget);

    await tester.tapAt(const Offset(400, 400));
    await tester.pump();

    expect(find.text('Tap away error'), findsNothing);
    await future;
  });
}
