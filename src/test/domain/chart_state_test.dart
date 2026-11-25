import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/account_balance.dart';
import 'package:overmind/domain/chart_state.dart';
import 'package:overmind/domain/money.dart';
import 'package:overmind/domain/open_positions.dart';
import 'package:overmind/domain/portfolio.dart';

Holding _holding(String timeframe,
    {double takeProfit = 10, double stopLoss = -5}) {
  return Holding(
    instrument: 'BTCUSDT',
    timeframe: timeframe,
    takeProfit: takeProfit,
    stopLoss: stopLoss,
    riskReward: 2,
    horizon: 60,
    horizonFormatted: '1h',
    allocation: 100,
    testingScore: 0.5,
    trainingScore: 0.8,
    outputScore: 0.7,
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

OpenPositions _positionsWith(
    {double takeProfitPrice = 110, double stopLossPrice = 90}) {
  return OpenPositions(
    balance: FuturesBalance.empty,
    positions: [
      PositionSnapshot(
        symbol: 'BTCUSDT',
        entryPrice: 100,
        positionAmount: 1,
        takeProfitPrice: takeProfitPrice,
        stopLossPrice: stopLossPrice,
        takeProfitProgress: 0,
        stopLossProgress: 0,
        unrealizedProfit: 0,
        initialMargin: 10,
      ),
    ],
  );
}

final Portfolio _portfolio = Portfolio(holdings: [
  _holding('5m'),
  _holding('30m', takeProfit: 30, stopLoss: -15),
]);

void main() {
  group('ChartState.levelsFor', () {
    test('reads recommended offsets from the primary and auxiliary timeframe',
        () {
      final state = ChartState.none.levelsFor(
        'BTCUSDT',
        portfolio: _portfolio,
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: OpenPositions.empty,
      );

      expect(state.plannedTakeProfit, 10);
      expect(state.plannedStopLoss, -5);
      expect(state.auxTakeProfit, 30);
      expect(state.auxStopLoss, -15);
      expect(state.takeProfitPrice, 0);
    });

    test('leaves auxiliary offsets at zero when the auxiliary signal is flat',
        () {
      final portfolio =
          Portfolio(holdings: [_holding('5m'), _holding('30m', takeProfit: 0)]);

      final state = ChartState.none.levelsFor(
        'BTCUSDT',
        portfolio: portfolio,
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: OpenPositions.empty,
      );

      expect(state.auxTakeProfit, 0);
      expect(state.auxStopLoss, 0);
    });

    test('keeps resting order prices even when there is no signal', () {
      final portfolio =
          Portfolio(holdings: [_holding('5m', takeProfit: 0, stopLoss: 0)]);

      final state = ChartState.none.levelsFor(
        'BTCUSDT',
        portfolio: portfolio,
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: _positionsWith(),
      );

      expect(state.plannedTakeProfit, 0);
      expect(state.takeProfitPrice, 110);
      expect(state.stopLossPrice, 90);
      expect(state.entryPrice, 100);
    });

    test('drops levels of the previously selected symbol', () {
      final held = ChartState.none.levelsFor(
        'BTCUSDT',
        portfolio: _portfolio,
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: _positionsWith(),
      );

      final switched = held.levelsFor(
        'ETHUSDT',
        portfolio: _portfolio,
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: OpenPositions.empty,
      );

      expect(switched.plannedTakeProfit, 0);
      expect(switched.takeProfitPrice, 0);
      expect(switched.entryPrice, 0);
      // The candle series still belongs to the chart, so its close survives.
      expect(switched.lastClose, held.lastClose);
    });

    test('a short signal prices the live candle off the bid', () {
      final short = ChartState.none.levelsFor(
        'BTCUSDT',
        portfolio:
            Portfolio(holdings: [_holding('5m', takeProfit: -10, stopLoss: 5)]),
        timeframe: '5m',
        auxTimeframe: '30m',
        positions: OpenPositions.empty,
      );

      expect(short.preferBid, isTrue);
      expect(
          ChartState.none
              .levelsFor(
                'BTCUSDT',
                portfolio: _portfolio,
                timeframe: '5m',
                auxTimeframe: '30m',
                positions: OpenPositions.empty,
              )
              .preferBid,
          isFalse);
    });
  });

  group('ChartState.copyWith', () {
    test('only replaces the fields given', () {
      final state = const ChartState(lastClose: 64000, entryPrice: 63900)
          .copyWith(takeProfitPrice: 64500);

      expect(state.takeProfitPrice, 64500);
      expect(state.lastClose, 64000);
      expect(state.entryPrice, 63900);
      expect(state.plannedTakeProfit, 0);
    });
  });

  group('formatCurrency', () {
    test('keeps small figures readable and large ones short', () {
      expect(formatCurrency(0.0004), '\$0.000400');
      expect(formatCurrency(0.5), '\$0.500');
      expect(formatCurrency(12.34), '\$12.3');
      expect(formatCurrency(1234), '\$1234');
      expect(formatCurrency(-7.5), '\$-7.50');
    });
  });
}
