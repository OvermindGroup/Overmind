import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/portfolio.dart';

Holding _holding({
  String instrument = 'BTCUSDT',
  String timeframe = '5m',
  double outputScore = 0.7,
  double testingScore = 0.5,
  double takeProfit = 10,
  double stopLoss = -5,
  double direction1 = 0.6,
  double direction2 = -0.6,
  double tpLower = 1,
  double tpUpper = 20,
}) {
  return Holding(
    instrument: instrument,
    timeframe: timeframe,
    takeProfit: takeProfit,
    stopLoss: stopLoss,
    riskReward: 2,
    horizon: 60,
    horizonFormatted: '1h',
    allocation: 100,
    testingScore: testingScore,
    trainingScore: 0.8,
    outputScore: outputScore,
    outputDelta: 0.1,
    outputActivation: 0.9,
    tpVolPerc: 0.05,
    slVolPerc: 0.05,
    direction1: direction1,
    direction2: direction2,
    tpLower: tpLower,
    tpUpper: tpUpper,
  );
}

void main() {
  group('Holding.calculateTradeFactor', () {
    test('trades nothing below the usable score', () {
      expect(_holding(outputScore: 0.59).calculateTradeFactor(), 0);
    });

    test('ramps between 0.6 and 0.8', () {
      expect(_holding(outputScore: 0.6).calculateTradeFactor(), 0.5);
      expect(_holding(outputScore: 0.7).calculateTradeFactor(), 0.75);
    });

    test('trades everything at or above 0.8', () {
      expect(_holding(outputScore: 0.8).calculateTradeFactor(), 1);
      expect(_holding(outputScore: 1).calculateTradeFactor(), 1);
    });
  });

  group('Portfolio.filteredBest', () {
    test('keeps a long signal whose directions oppose', () {
      final portfolio = Portfolio(holdings: [_holding()]);
      expect(portfolio.filteredBest().length, 1);
    });

    test('keeps a short signal whose directions oppose', () {
      final portfolio = Portfolio(
        holdings: [
          _holding(
              takeProfit: -10, stopLoss: 5, direction1: -0.6, direction2: 0.6)
        ],
      );
      expect(portfolio.filteredBest().length, 1);
    });

    test('drops a signal below the output score', () {
      final portfolio = Portfolio(holdings: [_holding(outputScore: 0.5)]);
      expect(portfolio.filteredBest().isEmpty, isTrue);
    });

    test('drops a signal with directions that do not oppose', () {
      final portfolio = Portfolio(holdings: [_holding(direction2: 0.1)]);
      expect(portfolio.filteredBest().isEmpty, isTrue);
    });

    test('drops a signal without a usable take-profit band', () {
      final portfolio = Portfolio(holdings: [_holding(tpLower: 0)]);
      expect(portfolio.filteredBest().isEmpty, isTrue);
    });

    // Regression: the filtered copy used to share its list with the full
    // portfolio, so filtering silently emptied the portfolio the chart and the
    // position table read their levels from.
    test('leaves the source portfolio untouched', () {
      final full =
          Portfolio(holdings: [_holding(), _holding(outputScore: 0.2)]);
      final filtered = full.filteredBest();

      expect(filtered.length, 1);
      expect(full.length, 2);
    });

    test('holdings cannot be mutated from outside', () {
      final holdings = [_holding()];
      final portfolio = Portfolio(holdings: holdings);
      expect(() => portfolio.holdings.add(_holding()), throwsUnsupportedError);
    });
  });

  group('Portfolio', () {
    test('symbols list each instrument once across timeframes', () {
      final portfolio = Portfolio(
        holdings: [_holding(timeframe: '5m'), _holding(timeframe: '30m')],
      );
      expect(portfolio.symbols, ['BTCUSDT']);
    });

    test('holdingFor matches instrument and timeframe', () {
      final portfolio = Portfolio(
        holdings: [_holding(timeframe: '5m'), _holding(timeframe: '30m')],
      );
      expect(portfolio.holdingFor('BTCUSDT', '30m')?.timeframe, '30m');
      expect(portfolio.holdingFor('ETHUSDT', '5m'), isNull);
    });

    test('subpar selects models below the testing score', () {
      final portfolio = Portfolio(
        holdings: [_holding(testingScore: 0.4), _holding(testingScore: 0.8)],
      );
      expect(portfolio.subpar(0.5).length, 1);
    });

    test('fromJson tolerates missing and malformed fields', () {
      final portfolio = Portfolio.fromJson([
        {'instrument': 'BTCUSDT', 'timeframe': '5m', 'outputScore': 0.9},
        'not a holding',
      ]);

      expect(portfolio.length, 1);
      expect(portfolio.holdings.single.takeProfit, 0);
      expect(portfolio.holdings.single.outputScore, 0.9);
    });

    test('lastTrades keeps only well-formed revenue pairs', () {
      final holding = Holding.fromJson({
        'instrument': 'BTCUSDT',
        'timeframe': '5m',
        'lastTrades': [
          [12.5, 1],
          ['nope', 1],
          [3],
        ],
      });

      expect(holding.lastTrades.length, 1);
      expect(holding.lastTrades.single.revenue, 12.5);
      expect(holding.lastTrades.single.direction, 1);
    });
  });
}
