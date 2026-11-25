import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/trades.dart';

TradeFill _fill({
  String orderId = '1',
  String symbol = 'BTCUSDT',
  String side = 'BUY',
  double realizedPnl = 0,
  double quantity = 1,
  double commission = 0.5,
  int time = 1000,
}) {
  return TradeFill.fromApi({
    'orderId': orderId,
    'symbol': symbol,
    'side': side,
    'price': '100',
    'qty': quantity.toString(),
    'realizedPnl': realizedPnl.toString(),
    'quoteQty': (quantity * 100).toString(),
    'commission': commission.toString(),
    'commissionAsset': 'USDT',
    'time': time,
  });
}

DateTime _at(int millis) => DateTime.fromMillisecondsSinceEpoch(millis);

void main() {
  group('TradeFill.fromApi', () {
    test('reads decimal strings and a millisecond timestamp', () {
      final fill = _fill(quantity: 0.5, realizedPnl: 12.5, time: 1700000000000);

      expect(fill.quantity, 0.5);
      expect(fill.realizedPnl, 12.5);
      expect(fill.time, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });
  });

  group('TradeSummary.analyse', () {
    test('merges partial fills of one order into a single closing leg', () {
      final summary = TradeSummary.analyse([
        _fill(orderId: 'open', quantity: 0.4, commission: 0.2),
        _fill(orderId: 'open', quantity: 0.6, commission: 0.3),
        _fill(
            orderId: 'close',
            realizedPnl: 8,
            quantity: 1,
            commission: 0.1,
            time: 2000),
      ]);

      expect(summary.tradeCount, 1);
      expect(summary.trades.single.quantity, 1);
      expect(summary.trades.single.realizedPnl, 8);
      // The two opening fills charged 0.5 in total, which belongs to this trade.
      expect(summary.trades.single.commission, closeTo(0.6, 0.0001));
    });

    test('carries the opening commission onto the closing leg', () {
      final summary = TradeSummary.analyse([
        _fill(commission: 0.5),
        _fill(realizedPnl: 10, commission: 0.25, time: 2000),
      ]);

      expect(summary.trades.single.commission, closeTo(0.75, 0.0001));
      expect(summary.totalPnlAfterFees, closeTo(9.25, 0.0001));
    });

    test('drops opening legs from the displayed trades', () {
      final summary = TradeSummary.analyse([
        _fill(orderId: 'open', realizedPnl: 0),
        _fill(orderId: 'close', realizedPnl: 4, time: 2000),
      ]);

      expect(summary.trades.map((trade) => trade.realizedPnl), [4]);
    });

    test('flips the side to the leg that closed the position', () {
      final summary = TradeSummary.analyse([
        _fill(side: 'BUY', realizedPnl: 4, time: 2000),
      ]);

      expect(summary.trades.single.side, 'SELL');
    });

    test('totals profit and counts winning trades', () {
      final summary = TradeSummary.analyse([
        _fill(orderId: 'a', realizedPnl: 10, time: 2000),
        _fill(orderId: 'b', realizedPnl: -4, time: 3000),
        _fill(orderId: 'c', realizedPnl: 2, time: 4000),
      ]);

      expect(summary.totalPnl, 8);
      expect(summary.winningTrades, 2);
      expect(summary.accuracy, closeTo(66.67, 0.01));
    });

    test('curves the running total oldest first', () {
      final summary = TradeSummary.analyse([
        _fill(orderId: 'a', realizedPnl: 10, time: 3000),
        _fill(orderId: 'b', realizedPnl: -4, time: 1000),
      ]);

      expect(summary.curve.map((point) => point.cumulative), [-4, 6]);
      expect(summary.curve[1].time, _at(3000));
    });

    test('lists displayed trades newest first', () {
      final summary = TradeSummary.analyse([
        _fill(orderId: 'a', realizedPnl: 10, time: 1000),
        _fill(orderId: 'b', realizedPnl: 5, time: 5000),
      ]);

      expect(summary.trades.map((trade) => trade.orderId), ['b', 'a']);
    });

    test('only counts fills inside the requested window', () {
      final summary = TradeSummary.analyse(
        [
          _fill(orderId: 'a', realizedPnl: 10, time: 1000),
          _fill(orderId: 'b', realizedPnl: 20, time: 5000),
        ],
        from: _at(2000),
        to: _at(6000),
      );

      expect(summary.totalPnl, 20);
      expect(summary.tradeCount, 1);
    });

    test('an empty window reads as no trades', () {
      final summary = TradeSummary.analyse(const []);

      expect(summary.tradeCount, 0);
      expect(summary.accuracy, 0);
      expect(summary.curve, isEmpty);
    });
  });
}
