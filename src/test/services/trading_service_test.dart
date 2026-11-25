import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/api_keys.dart';
import 'package:overmind/domain/portfolio.dart';
import 'package:overmind/domain/trade_settings.dart';
import 'package:overmind/services/binance_api.dart';
import 'package:overmind/services/overmind_api.dart';
import 'package:overmind/services/position_tracker.dart';
import 'package:overmind/services/trading_service.dart';

import '../stub_http_client.dart';

const ApiKeys _keys = ApiKeys(
  binanceApiKey: 'k',
  binanceApiSecret: 's',
  overmindApiKey: 'o',
);

Holding _holding({
  double outputScore = 0.7,
  double takeProfit = 10,
  double stopLoss = -5,
}) {
  return Holding(
    instrument: 'BTCUSDT',
    timeframe: '5m',
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

/// A market at 100, a margin account with [available] USDT free, and orders
/// that always succeed.
Map<String, List<StubReply>> _healthyRoutes({double available = 60}) => {
      '/v1/meta/latestPrice': [
        StubReply.json({'close': '100'})
      ],
      '/api/v3/ticker/price': [
        StubReply.json({'symbol': 'BTCUSDT', 'price': '100'})
      ],
      '/fapi/v1/exchangeInfo': [
        StubReply.json({
          'symbols': [
            {
              'symbol': 'BTCUSDT',
              'pricePrecision': 2,
              'quantityPrecision': 3,
              'filters': [
                {'filterType': 'MIN_NOTIONAL', 'notional': '20'},
                {
                  'filterType': 'LOT_SIZE',
                  'stepSize': '0.01',
                  'minQty': '0.01'
                },
              ],
            },
          ],
        }),
      ],
      '/fapi/v2/balance': [
        StubReply.json([
          {
            'asset': 'USDT',
            'balance': '100',
            'availableBalance': available.toString(),
            'crossUnPnl': '0',
          },
        ]),
      ],
      '/fapi/v1/leverage': [
        StubReply.json({'lever': 1})
      ],
      '/fapi/v1/allOpenOrders': [
        StubReply.json({'code': 200, 'msg': ''})
      ],
      '/fapi/v1/algoOrder': [
        StubReply.json({'algoStatus': 'NEW'})
      ],
      '/fapi/v1/order': [
        StubReply.json({'status': 'NEW'})
      ],
      '/fapi/v3/positionRisk': [StubReply.json(<Object>[])],
      '/fapi/v1/openAlgoOrders': [StubReply.json(<Object>[])],
    };

/// A service whose Binance traffic goes through one stub, so a test can assert
/// on the requests while the position tracker still refreshes from them.
(TradingService, StubClient) _serviceWith(Map<String, List<StubReply>> routes) {
  final binanceClient = StubClient(routes);
  final binance = BinanceApi(client: binanceClient);
  return (
    TradingService(
      binance: binance,
      overmind: OvermindApi(client: StubClient(routes)),
      positions: PositionTracker(binance: binance),
    ),
    binanceClient,
  );
}

List<Uri> _paths(StubClient client, String path) => client.requests
    .where((request) => request.url.path == path)
    .map((request) => request.url)
    .toList();

void main() {
  group('openPosition', () {
    test('rests both orders before entering at market', () async {
      final (service, binanceClient) = _serviceWith(_healthyRoutes());
      final outcome = await service.openPosition(_keys, _holding(), 50, 1);

      expect(outcome.success, isTrue);
      expect(outcome.message, 'BTCUSDT: position opened');

      final conditional = _paths(binanceClient, '/fapi/v1/algoOrder');
      expect(conditional.length, 2);
      expect(conditional.first.queryParameters['type'], 'TAKE_PROFIT_MARKET');
      expect(conditional.first.queryParameters['side'], 'SELL');
      expect(conditional.first.queryParameters['triggerPrice'], '110.00');
      expect(conditional.last.queryParameters['type'], 'STOP_MARKET');
      expect(conditional.last.queryParameters['triggerPrice'], '95.00');

      final market = _paths(binanceClient, '/fapi/v1/order').last;
      expect(market.queryParameters['side'], 'BUY');
      // 50 USDT allocation times the 0.75 trade factor, at a price of 100.
      expect(market.queryParameters['quantity'], '0.375');
    });

    test('refuses a signal too weak to trade without calling the exchange',
        () async {
      final (service, binanceClient) = _serviceWith(_healthyRoutes());
      final outcome =
          await service.openPosition(_keys, _holding(outputScore: 0.4), 50, 1);

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('too weak to trade'));
      expect(binanceClient.requests, isEmpty);
    });

    test('refuses when the margin account cannot cover the allocation',
        () async {
      final outcome = await _serviceWith(_healthyRoutes(available: 10))
          .$1
          .openPosition(_keys, _holding(), 50, 1);

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('only \$10.00 available'));
    });

    test('refuses when no allocation is configured', () async {
      final outcome = await _serviceWith(_healthyRoutes())
          .$1
          .openPosition(_keys, _holding(), 0, 1);

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('allocation'));
    });

    test('refuses a quantity below the lot rule', () async {
      final outcome = await _serviceWith(_healthyRoutes())
          .$1
          .openPosition(_keys, _holding(), 1, 1);

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('below the exchange minimum'));
    });

    test('stops before entering when the take-profit order is rejected',
        () async {
      final routes = _healthyRoutes();
      routes['/fapi/v1/algoOrder'] = [
        StubReply.json(
            {'algoStatus': 'REJECTED', 'msg': 'trigger below market'}),
        StubReply.json({'algoStatus': 'NEW'}),
      ];

      final (service, client) = _serviceWith(routes);
      final outcome = await service.openPosition(_keys, _holding(), 50, 1);

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('take profit order rejected'));
      expect(_paths(client, '/fapi/v1/order'), isEmpty);
    });
  });

  group('executePortfolio', () {
    test('skips instruments that are already held', () async {
      final routes = _healthyRoutes();
      routes['/fapi/v3/positionRisk'] = [
        StubReply.json([
          {
            'symbol': 'BTCUSDT',
            'positionAmt': '0.375',
            'entryPrice': '100',
            'unRealizedProfit': '1',
            'initialMargin': '37.5',
          },
        ]),
      ];

      final (service, client) = _serviceWith(routes);
      final outcomes = await service.executePortfolio(
        _keys,
        Portfolio(holdings: [_holding()]),
        const TradeSettings(allocationUsdt: 50, leverage: 1),
      );

      expect(outcomes, isEmpty);
      expect(_paths(client, '/fapi/v1/order'), isEmpty);
    });

    test('trades an instrument that is not held yet', () async {
      final (service, client) = _serviceWith(_healthyRoutes());
      final outcomes = await service.executePortfolio(
        _keys,
        Portfolio(holdings: [_holding()]),
        const TradeSettings(allocationUsdt: 50, leverage: 1),
      );

      expect(outcomes.single.success, isTrue);
      expect(_paths(client, '/fapi/v1/order'), hasLength(1));
    });
  });

  group('re-pointing resting orders', () {
    test('keeps the side and quantity of the order being replaced', () async {
      final routes = _healthyRoutes();
      routes['/fapi/v1/openAlgoOrders'] = [
        StubReply.json([
          {
            'orderId': 5,
            'type': 'TAKE_PROFIT_MARKET',
            'side': 'SELL',
            'origQty': '0.5',
            'triggerPrice': '70'
          },
          {
            'orderId': 6,
            'type': 'STOP_MARKET',
            'side': 'SELL',
            'origQty': '0.5',
            'triggerPrice': '80'
          },
        ]),
      ];
      // The first call to /fapi/v1/order is the cancel; the reply must say CANCELED.
      routes['/fapi/v1/order'] = [
        StubReply.json({'status': 'CANCELED'}),
        StubReply.json({'status': 'NEW'}),
      ];

      final (service, client) = _serviceWith(routes);
      final outcome = await service.updateTakeProfit(
          _keys, 'BTCUSDT', _holding(takeProfit: 10));

      expect(outcome.success, isTrue);
      expect(outcome.message, 'BTCUSDT take profit order updated');

      final canceled = client.requests
          .firstWhere((request) => request.url.path == '/fapi/v1/order');
      expect(canceled.method, 'DELETE');
      expect(canceled.url.queryParameters['orderId'], '5');

      final created = _paths(client, '/fapi/v1/algoOrder').last;
      expect(created.queryParameters['type'], 'TAKE_PROFIT_MARKET');
      expect(created.queryParameters['side'], 'SELL');
      expect(created.queryParameters['quantity'], '0.5');
      expect(created.queryParameters['triggerPrice'], '110.00');
    });

    test('reports when there is no order of that type to update', () async {
      final routes = _healthyRoutes();
      routes['/fapi/v1/openAlgoOrders'] = [
        StubReply.json([
          {
            'orderId': 6,
            'type': 'STOP_MARKET',
            'side': 'SELL',
            'origQty': '0.5',
            'triggerPrice': '80'
          },
        ]),
      ];

      final outcome = await _serviceWith(routes)
          .$1
          .updateTakeProfit(_keys, 'BTCUSDT', _holding());

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('no take profit order'));
    });

    test('closes the position when the new levels contradict it', () async {
      final routes = _healthyRoutes();
      routes['/fapi/v3/positionRisk'] = [
        StubReply.json([
          {
            'symbol': 'BTCUSDT',
            'positionAmt': '0.5',
            'entryPrice': '100',
            'unRealizedProfit': '0',
            'initialMargin': '50',
          },
        ]),
      ];

      final (service, client) = _serviceWith(routes);
      // A long whose stop loss sits above the take profit cannot be re-pointed.
      final outcome = await service.updateBoth(
          _keys, 'BTCUSDT', _holding(takeProfit: 5, stopLoss: 20));

      expect(outcome.success, isTrue);
      expect(outcome.message, 'BTCUSDT position and stop orders closed');
      expect(_paths(client, '/fapi/v1/algoOrder'), isEmpty);
    });

    test('a symbol with nothing held cannot be closed', () async {
      final outcome = await _serviceWith(_healthyRoutes())
          .$1
          .closePosition(_keys, 'BTCUSDT');

      expect(outcome.success, isFalse);
      expect(outcome.message, contains('no open position'));
    });
  });
}
