import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/account_balance.dart';
import 'package:overmind/domain/exchange.dart';
import 'package:overmind/domain/open_positions.dart';

OpenOrder _order(String type, double triggerPrice, {String orderId = '1'}) {
  return OpenOrder(
    orderId: orderId,
    type: type,
    side: 'SELL',
    quantity: '1',
    triggerPrice: triggerPrice,
  );
}

OpenPosition _position({
  double entryPrice = 100,
  double positionAmount = 1,
  double unrealizedProfit = 5,
  double initialMargin = 10,
}) {
  return OpenPosition(
    symbol: 'BTCUSDT',
    entryPrice: entryPrice,
    positionAmount: positionAmount,
    unrealizedProfit: unrealizedProfit,
    initialMargin: initialMargin,
  );
}

void main() {
  group('OpenPosition.tryFrom', () {
    // Regression: flat rows from positionRisk used to be counted as positions,
    // which stopped the auto trader from opening real ones.
    test('drops flat rows', () {
      expect(OpenPosition.tryFrom({'symbol': 'BTCUSDT', 'positionAmt': '0'}),
          isNull);
    });

    test('reads a long position', () {
      final position = OpenPosition.tryFrom({
        'symbol': 'BTCUSDT',
        'positionAmt': '0.5',
        'entryPrice': '64000.5',
        'unRealizedProfit': '12.25',
        'initialMargin': '32',
      });

      expect(position?.positionAmount, 0.5);
      expect(position?.entryPrice, 64000.5);
      expect(position?.unrealizedProfit, 12.25);
      expect(position?.initialMargin, 32);
    });
  });

  group('OpenOrder.tryFrom', () {
    test('accepts the field names the futures endpoint uses', () {
      final order = OpenOrder.tryFrom({
        'orderId': 7,
        'type': 'STOP_MARKET',
        'side': 'BUY',
        'origQty': '0.5',
        'triggerPrice': '60000',
      });

      expect(order?.orderId, '7');
      expect(order?.isStopLoss, isTrue);
      expect(order?.quantity, '0.5');
      expect(order?.triggerPrice, 60000);
    });

    test('accepts the field names the algo endpoint uses', () {
      final order = OpenOrder.tryFrom({
        'algoId': 7,
        'orderType': 'TAKE_PROFIT_MARKET',
        'quantity': '0.5',
        'stopPrice': '70000',
      });

      expect(order?.isTakeProfit, isTrue);
      expect(order?.triggerPrice, 70000);
    });

    test('rejects rows without an order id or type', () {
      expect(OpenOrder.tryFrom({'triggerPrice': '70000'}), isNull);
    });
  });

  group('PositionSnapshot.from', () {
    test('maps take profit and stop loss in the order they were returned', () {
      final snapshot = PositionSnapshot.from(
        position: _position(),
        orders: [
          _order('TAKE_PROFIT_MARKET', 110, orderId: '1'),
          _order('STOP_MARKET', 90, orderId: '2')
        ],
      );

      expect(snapshot.takeProfitPrice, 110);
      expect(snapshot.stopLossPrice, 90);
    });

    test('swaps them when a stop loss comes first', () {
      final snapshot = PositionSnapshot.from(
        position: _position(),
        orders: [
          _order('STOP_MARKET', 90, orderId: '1'),
          _order('TAKE_PROFIT_MARKET', 110, orderId: '2')
        ],
      );

      expect(snapshot.takeProfitPrice, 110);
      expect(snapshot.stopLossPrice, 90);
    });

    test('reports progress toward take profit while in profit', () {
      final snapshot = PositionSnapshot.from(
        position: _position(),
        orders: [_order('TAKE_PROFIT_MARKET', 110), _order('STOP_MARKET', 90)],
      );

      // The margin controls 10% of the entry price, so reaching 110 gains 1.
      // The position is already 5 ahead, which is five times that level: the
      // bar is clamped to full by the widget.
      expect(snapshot.takeProfitProgress, closeTo(500, 0.0001));
      expect(snapshot.stopLossProgress, 0);
    });

    test('reports progress toward stop loss while at a loss', () {
      final snapshot = PositionSnapshot.from(
        position: _position(unrealizedProfit: -0.5),
        orders: [_order('TAKE_PROFIT_MARKET', 110), _order('STOP_MARKET', 90)],
      );

      expect(snapshot.takeProfitProgress, 0);
      expect(snapshot.stopLossProgress, closeTo(50, 0.0001));
    });

    test('leaves progress at zero when no orders rest', () {
      final snapshot =
          PositionSnapshot.from(position: _position(), orders: const []);

      expect(snapshot.takeProfitPrice, 0);
      expect(snapshot.takeProfitProgress, 0);
      expect(snapshot.stopLossProgress, 0);
    });

    // Regression: a zero potential divided into the travelled amount used to
    // publish Infinity, which filled the progress bars to the edge.
    test('does not divide by zero when the level is unreachable', () {
      final snapshot = PositionSnapshot.from(
        position: _position(entryPrice: 0, initialMargin: 0),
        orders: [_order('TAKE_PROFIT_MARKET', 0)],
      );

      expect(snapshot.takeProfitProgress.isFinite, isTrue);
      expect(snapshot.takeProfitProgress, 0);
    });

    test('labels margin by direction', () {
      expect(_snapshotFor(1).marginLabel, '+\$10.00');
      expect(_snapshotFor(-1).marginLabel, '-\$10.00');
    });
  });

  group('OpenPositions', () {
    test('finds the position for a symbol', () {
      final positions = OpenPositions(
        balance: FuturesBalance.empty,
        positions: [
          _snapshotFor(1),
          _snapshotFor(-1, symbol: 'ETHUSDT'),
        ],
      );

      expect(positions.positionFor('ETHUSDT')?.symbol, 'ETHUSDT');
      expect(positions.hasPositionFor('SOLUSDT'), isFalse);
      expect(positions.count, 2);
    });

    test('the empty snapshot is usable', () {
      expect(OpenPositions.empty.isEmpty, isTrue);
      expect(OpenPositions.empty.balance.availableBalance, 0);
    });
  });

  group('FuturesBalance.fromApi', () {
    test('parses the decimal strings Binance returns', () {
      final balance = FuturesBalance.fromApi({
        'asset': 'USDT',
        'balance': '150.25',
        'availableBalance': '120.5',
        'crossUnPnl': '-3.25',
      });

      expect(balance.totalBalance, 150.25);
      expect(balance.availableBalance, 120.5);
      expect(balance.unrealizedProfit, -3.25);
      expect(balance.canAfford(120.5), isTrue);
      expect(balance.canAfford(121), isFalse);
    });

    test('treats missing fields as zero', () {
      expect(FuturesBalance.fromApi(const {}).availableBalance, 0);
    });
  });
}

PositionSnapshot _snapshotFor(double amount, {String symbol = 'BTCUSDT'}) {
  return PositionSnapshot.from(
    position: OpenPosition(
      symbol: symbol,
      entryPrice: 100,
      positionAmount: amount,
      unrealizedProfit: 0,
      initialMargin: 10,
    ),
    orders: const [],
  );
}
