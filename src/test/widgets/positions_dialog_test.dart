import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/account_balance.dart';
import 'package:overmind/domain/action_result.dart';
import 'package:overmind/domain/open_positions.dart';
import 'package:overmind/widgets/positions.dart';

PositionSnapshot _snapshot(
  String symbol, {
  double amount = 1,
  double profit = 5,
  double takeProfitProgress = 40,
  double stopLossProgress = 20,
  double margin = 30,
}) {
  return PositionSnapshot(
    symbol: symbol,
    entryPrice: 100,
    positionAmount: amount,
    takeProfitPrice: 110,
    stopLossPrice: 90,
    takeProfitProgress: takeProfitProgress,
    stopLossProgress: stopLossProgress,
    unrealizedProfit: profit,
    initialMargin: margin,
  );
}

OpenPositions _open({List<PositionSnapshot> positions = const []}) =>
    OpenPositions(
      balance: const FuturesBalance(
        totalBalance: 100,
        availableBalance: 70,
        unrealizedProfit: 12.5,
      ),
      positions: positions,
    );

PositionActions _actions({void Function(String)? onView}) => PositionActions(
      viewPosition: onView ?? (_) {},
      updateTakeProfit: (symbol) async =>
          ActionResult('$symbol take profit order updated'),
      updateStopLoss: (symbol) async =>
          ActionResult('$symbol stop loss order updated'),
      updateBoth: (symbol) async =>
          ActionResult('$symbol take profit and stop loss updated'),
      closePosition: (symbol) async =>
          ActionResult('$symbol position and orders closed'),
    );

void main() {
  testWidgets('shows the balance and one row per position', (tester) async {
    final notifier = ValueNotifier(_open(
        positions: [_snapshot('BTCUSDT'), _snapshot('ETHUSDT', amount: -1)]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionsDialog(positions: notifier, actions: _actions()),
        ),
      ),
    );

    expect(find.text('Total Balance:'), findsOneWidget);
    expect(find.text('\$100'), findsOneWidget);
    expect(find.text('Unrealized Profit:'), findsOneWidget);
    expect(find.text('\$12.5'), findsOneWidget);
    expect(find.text('Open Positions:'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    expect(find.text('BTCUSDT'), findsOneWidget);
    expect(find.text('ETHUSDT'), findsOneWidget);
    expect(find.text('-\$30.00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
  });

  testWidgets('sorts the biggest profit first', (tester) async {
    final notifier = ValueNotifier(_open(positions: [
      _snapshot('LOW', profit: 1),
      _snapshot('HIGH', profit: 9),
    ]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
            body: PositionsDialog(positions: notifier, actions: _actions())),
      ),
    );

    final rows =
        tester.widgetList<DataTable>(find.byType(DataTable)).single.rows;

    // The first column holds the actions, so read the symbol from the second.
    final symbols =
        rows.map((row) => (row.cells[1].child as Text).data).toList();
    expect(symbols, ['HIGH', 'LOW']);
  });

  testWidgets('says there is nothing to show when flat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionsDialog(
              positions: ValueNotifier(_open()), actions: _actions()),
        ),
      ),
    );

    expect(find.text('No open positions to display'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('progress bars never overflow their level', (tester) async {
    final notifier = ValueNotifier(
        _open(positions: [_snapshot('BTCUSDT', takeProfitProgress: 500)]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
            body: PositionsDialog(positions: notifier, actions: _actions())),
      ),
    );

    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars.first.value, 1);
  });

  testWidgets('view position reports the symbol it was pressed on',
      (tester) async {
    var viewed = '';
    final notifier = ValueNotifier(_open(positions: [_snapshot('BTCUSDT')]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionsDialog(
              positions: notifier,
              actions: _actions(onView: (symbol) => viewed = symbol)),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.visibility));
    expect(viewed, 'BTCUSDT');
  });

  testWidgets('rows update as the tracker publishes new positions',
      (tester) async {
    final notifier = ValueNotifier(_open());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
            body: PositionsDialog(positions: notifier, actions: _actions())),
      ),
    );

    expect(find.text('No open positions to display'), findsOneWidget);

    notifier.value = _open(positions: [_snapshot('BTCUSDT')]);
    await tester.pump();

    expect(find.text('BTCUSDT'), findsOneWidget);
  });
}
