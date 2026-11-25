import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/action_result.dart';
import 'package:overmind/domain/open_positions.dart';
import 'package:overmind/domain/portfolio.dart';
import 'package:overmind/domain/trade_settings.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:overmind/widgets/feedback.dart';
import 'package:overmind/widgets/portfolio_panel.dart';

Holding _holding(String instrument, String timeframe,
    {double outputScore = 0.85, double takeProfit = 10, double stopLoss = -5}) {
  return Holding(
    instrument: instrument,
    timeframe: timeframe,
    takeProfit: takeProfit,
    stopLoss: stopLoss,
    riskReward: 2,
    horizon: 60,
    horizonFormatted: '1h',
    allocation: 100,
    testingScore: 0.5,
    trainingScore: 0.8,
    outputScore: outputScore,
    outputDelta: 0.1,
    outputActivation: 0.9,
    tpVolPerc: 0.05,
    slVolPerc: 0.05,
    direction1: 0.6,
    direction2: -0.6,
    tpLower: 1,
    tpUpper: 20,
  );
}

Portfolio _portfolio() => Portfolio(holdings: [
      _holding('BTCUSDT', '5m'),
      _holding('BTCUSDT', '30m', takeProfit: 30, stopLoss: -15),
      _holding('ETHUSDT', '5m', takeProfit: 20, stopLoss: -10),
    ]);

/// The dashboard's tables scroll horizontally, so tests press the control's
/// handler instead of relying on a hit test at an off-screen location.
///
/// Matches on the icon rather than the icon's own finder, because the training
/// buttons use the same icon inside an ElevatedButton.
IconButton _iconButton(WidgetTester tester, IconData icon) {
  return tester.widget<IconButton>(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.icon is Icon &&
              (widget.icon as Icon).icon == icon,
        )
        .first,
  );
}

void main() {
  testWidgets('lists every trained signal and prices the levels it recommends',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: FToastBuilder(),
        home: Scaffold(
          body: OptimizedPortfolioDialog(
            portfolio: _portfolio(),
            latestPrices: const {'BTCUSDT': 100, 'ETHUSDT': 300},
            positions: ValueNotifier(OpenPositions.empty),
            tradeSettings: const TradeSettings(allocationUsdt: 50, leverage: 3),
            onTradeSettingsChanged: (_) {},
            actions: PortfolioActions(
              trainPortfolio: () async => _portfolio(),
              resetPortfolio: () async => _portfolio(),
              trainModel: (holding) async => _portfolio(),
              resetModel: (holding) async => _portfolio(),
              tradeHolding: (holding) async =>
                  ActionResult('${holding.instrument}: position opened'),
              selectSymbol: (_) {},
              updateTakeProfit: (symbol) async =>
                  ActionResult('$symbol updated'),
              updateStopLoss: (symbol) async => ActionResult('$symbol updated'),
              updateBoth: (symbol) async => ActionResult('$symbol updated'),
              closePosition: (symbol) async => ActionResult('$symbol updated'),
            ),
          ),
        ),
      ),
    );

    // Three signals: BTCUSDT on two timeframes, ETHUSDT on one.
    expect(find.text('BTCUSDT'), findsNWidgets(2));
    expect(find.text('ETHUSDT'), findsOneWidget);

    // Offsets are shown as the price the order would rest at.
    expect(find.text('110.0000000'), findsOneWidget);
    expect(find.text('95.0000000'), findsOneWidget);
    expect(find.text('320.0000000'), findsOneWidget);

    // Only the primary timeframe gets buttons.
    expect(find.byIcon(Icons.paid), findsNWidgets(2));
    expect(find.text('No open positions to display'), findsOneWidget);
  });

  testWidgets('the search box narrows the table by instrument', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: FToastBuilder(),
        home: Scaffold(
          body: OptimizedPortfolioDialog(
            portfolio: _portfolio(),
            latestPrices: const {},
            positions: ValueNotifier(OpenPositions.empty),
            tradeSettings: TradeSettings.defaults,
            onTradeSettingsChanged: (_) {},
            actions: _noopActions(),
          ),
        ),
      ),
    );

    final search =
        find.widgetWithText(TextField, 'Search Assets (comma separated)');
    await tester.enterText(search, 'eth, btc');
    await tester.pump();

    // BTCUSDT appears on both timeframes, ETHUSDT on one.
    expect(find.text('BTCUSDT'), findsNWidgets(2));
    expect(find.text('ETHUSDT'), findsOneWidget);

    await tester.enterText(search, 'sol');
    await tester.pump();

    expect(find.text('BTCUSDT'), findsNothing);
    expect(find.text('ETHUSDT'), findsNothing);
  });

  testWidgets('trading a signal reports what the exchange did', (tester) async {
    var traded = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        builder: FToastBuilder(),
        home: Scaffold(
          body: OptimizedPortfolioDialog(
            portfolio: _portfolio(),
            latestPrices: const {},
            positions: ValueNotifier(OpenPositions.empty),
            tradeSettings: TradeSettings.defaults,
            onTradeSettingsChanged: (_) {},
            actions: _noopActions(
              tradeHolding: (holding) async {
                traded.add(holding.instrument);
                return ActionResult('${holding.instrument}: position opened');
              },
            ),
          ),
        ),
      ),
    );

    initToasts(tester.element(find.byType(OptimizedPortfolioDialog)));

    final tradeButton = _iconButton(tester, Icons.paid);
    tradeButton.onPressed?.call();
    await tester.pump();

    expect(traded, ['BTCUSDT']);
    expect(find.text('BTCUSDT: position opened'), findsOneWidget);

    // Dismissing explicitly also clears the toast's own timer, which the test
    // framework would otherwise report as pending.
    fToast.removeCustomToast();
    await tester.pump();
    expect(find.text('BTCUSDT: position opened'), findsNothing);
  });

  testWidgets('editing the allocation and leverage is reported upward',
      (tester) async {
    final changes = <TradeSettings>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptimizedPortfolioDialog(
            portfolio: _portfolio(),
            latestPrices: const {},
            positions: ValueNotifier(OpenPositions.empty),
            tradeSettings: const TradeSettings(allocationUsdt: 50, leverage: 3),
            onTradeSettingsChanged: changes.add,
            actions: _noopActions(),
          ),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '120');
    await tester.enterText(fields.last, '5');
    await tester.pump();

    expect(changes.map((settings) => settings.allocationUsdt), [120, 50]);
    expect(changes.map((settings) => settings.leverage), [3, 5]);
  });

  testWidgets('a portfolio action re-selects the signal it trained',
      (tester) async {
    final selected = <String>[];
    var trainedModels = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptimizedPortfolioDialog(
            portfolio: _portfolio(),
            latestPrices: const {},
            positions: ValueNotifier(OpenPositions.empty),
            tradeSettings: TradeSettings.defaults,
            onTradeSettingsChanged: (_) {},
            actions: _noopActions(
              selectSymbol: selected.add,
              trainModel: (holding) async {
                trainedModels.add(holding.instrument);
                return _portfolio();
              },
            ),
          ),
        ),
      ),
    );

    final trainPortfolio = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Train Full Portfolio'));
    trainPortfolio.onPressed?.call();
    await tester.pump();
    expect(trainedModels, isEmpty);

    final trainAsset = _iconButton(tester, Icons.fitness_center);
    trainAsset.onPressed?.call();
    await tester.pump();

    expect(trainedModels, ['BTCUSDT']);
    expect(selected, ['BTCUSDT']);
  });
}

PortfolioActions _noopActions({
  Future<ActionResult> Function(Holding)? tradeHolding,
  Future<Portfolio> Function(Holding)? trainModel,
  void Function(String)? selectSymbol,
}) {
  return PortfolioActions(
    trainPortfolio: () async => Portfolio.empty,
    resetPortfolio: () async => Portfolio.empty,
    trainModel: trainModel ?? (holding) async => Portfolio.empty,
    resetModel: (holding) async => Portfolio.empty,
    tradeHolding: tradeHolding ??
        (holding) async =>
            ActionResult('${holding.instrument}: position opened'),
    selectSymbol: selectSymbol ?? (_) {},
    updateTakeProfit: (symbol) async => ActionResult('$symbol updated'),
    updateStopLoss: (symbol) async => ActionResult('$symbol updated'),
    updateBoth: (symbol) async => ActionResult('$symbol updated'),
    closePosition: (symbol) async => ActionResult('$symbol updated'),
  );
}
