import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/api_keys.dart';
import 'package:overmind/services/binance_api.dart';

import '../stub_http_client.dart';

const ApiKeys _keys = ApiKeys(binanceApiKey: 'key', binanceApiSecret: 'secret');

void main() {
  group('private requests', () {
    test('sign and authenticate every signed call', () async {
      final client = StubClient({
        '/fapi/v3/positionRisk': [
          StubReply.json([
            {
              'symbol': 'BTCUSDT',
              'positionAmt': '1',
              'entryPrice': '100',
              'unRealizedProfit': '1',
              'initialMargin': '10'
            },
          ]),
        ],
      });

      await BinanceApi(client: client).getUserOpenPositions(_keys);

      final url = client.requests.single.url;
      expect(url.queryParameters['timestamp'], isNotNull);
      expect(
          url.queryParameters['signature'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(url.queryParameters['signature'],
          isNot(url.queryParameters['timestamp']));
    });

    test('a failed response is reported with the endpoint and body', () async {
      final client = StubClient({
        '/fapi/v1/leverage': [
          StubReply('{"code":400,"msg":"invalid leverage"}', statusCode: 400)
        ],
      });

      await expectLater(
        BinanceApi(client: client).changeLeverage(_keys, 'BTCUSDT', 0),
        throwsA(isA<BinanceException>().having(
          (error) => error.toString(),
          'message',
          contains('/fapi/v1/leverage'),
        )),
      );
    });

    test('a read that cannot be served degrades instead of throwing', () async {
      final client = StubClient({
        '/fapi/v3/positionRisk': [StubReply('unavailable', statusCode: 503)],
      });

      expect(await BinanceApi(client: client).getUserOpenPositions(_keys),
          isEmpty);
    });
  });

  group('positions and orders', () {
    test('flat rows are not reported as positions', () async {
      final client = StubClient({
        '/fapi/v3/positionRisk': [
          StubReply.json([
            {'symbol': 'BTCUSDT', 'positionAmt': '0'},
            {
              'symbol': 'ETHUSDT',
              'positionAmt': '-0.5',
              'entryPrice': '3000',
              'unRealizedProfit': '-10',
              'initialMargin': '40'
            },
          ]),
        ],
      });

      final positions =
          await BinanceApi(client: client).getUserOpenPositions(_keys);

      expect(positions.map((position) => position.symbol), ['ETHUSDT']);
      expect(positions.single.positionAmount, -0.5);
    });

    test('conditional orders keep the fields both endpoints send', () async {
      final client = StubClient({
        '/fapi/v1/openAlgoOrders': [
          StubReply.json([
            {
              'orderId': 5,
              'type': 'TAKE_PROFIT_MARKET',
              'side': 'SELL',
              'origQty': '0.5',
              'triggerPrice': '65000'
            },
            {
              'algoId': 6,
              'orderType': 'STOP_MARKET',
              'side': 'SELL',
              'quantity': '0.5',
              'stopPrice': '60000'
            },
          ]),
        ],
      });

      final orders =
          await BinanceApi(client: client).getUserOpenOrders(_keys, 'BTCUSDT');

      expect(orders.length, 2);
      expect(orders.first.isTakeProfit, isTrue);
      expect(orders.last.isStopLoss, isTrue);
      expect(orders.last.triggerPrice, 60000);
    });

    test('balance comes from the quote asset only', () async {
      final client = StubClient({
        '/fapi/v2/balance': [
          StubReply.json([
            {'asset': 'BTC', 'balance': '1'},
            {
              'asset': 'USDT',
              'balance': '200',
              'availableBalance': '150',
              'crossUnPnl': '-4.5'
            },
          ]),
        ],
      });

      final balance =
          await BinanceApi(client: client).getUserBalance(_keys, 'USDT');

      expect(balance.totalBalance, 200);
      expect(balance.availableBalance, 150);
      expect(balance.unrealizedProfit, -4.5);
    });

    test('a missing quote asset reads as an empty balance', () async {
      final client = StubClient({
        '/fapi/v2/balance': [
          StubReply.json([
            {'asset': 'BTC', 'balance': '1'}
          ])
        ],
      });

      expect(
          (await BinanceApi(client: client).getUserBalance(_keys, 'USDT'))
              .availableBalance,
          0);
    });
  });

  group('market data', () {
    test('a single symbol ticker is read as one object', () async {
      final client = StubClient({
        '/api/v3/ticker/price': [
          StubReply.json({'symbol': 'BTCUSDT', 'price': '64000.5'})
        ],
      });

      expect(await BinanceApi(client: client).getPrices(['BTCUSDT']),
          {'BTCUSDT': 64000.5});
    });

    test('several symbols are sent as a JSON array and read as a list',
        () async {
      final client = StubClient({
        '/api/v3/ticker/price': [
          StubReply.json([
            {'symbol': 'BTCUSDT', 'price': '64000'},
            {'symbol': 'ETHUSDT', 'price': '3000'},
          ]),
        ],
      });

      final prices =
          await BinanceApi(client: client).getPrices(['BTCUSDT', 'ETHUSDT']);

      expect(
          client.lastUrl.queryParameters['symbols'], '["BTCUSDT","ETHUSDT"]');
      expect(prices, {'BTCUSDT': 64000, 'ETHUSDT': 3000});
    });

    test('the book gives bid and ask', () async {
      final client = StubClient({
        '/fapi/v1/ticker/bookTicker': [
          StubReply.json(
              {'symbol': 'BTCUSDT', 'bidPrice': '63990', 'askPrice': '64010'}),
        ],
      });

      final book = await BinanceApi(client: client).getBookPrices(['BTCUSDT']);

      expect(book['BTCUSDT']?.bid, 63990);
      expect(book['BTCUSDT']?.ask, 64010);
    });

    test('minimum quantity satisfies the notional requirement', () async {
      final client = StubClient({
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
                  {'filterType': 'PRICE_FILTER', 'tickSize': '0.1'},
                  {'filterType': 'MIN_NOTIONAL', 'notional': '20'},
                  {
                    'filterType': 'LOT_SIZE',
                    'stepSize': '0.001',
                    'minQty': '0.001'
                  },
                ],
              },
            ],
          }),
        ],
      });

      final precision = await BinanceApi(client: client)
          .futuresMinimumQuantities(['BTCUSDT']);

      expect(precision['BTCUSDT']?.pricePrecision, 2);
      expect(precision['BTCUSDT']?.quantityPrecision, 3);
      expect(precision['BTCUSDT']?.minNotional, 20);
      // 20 USDT notional at 100 is 0.2 units, raised to the lot step.
      expect(precision['BTCUSDT']?.minQuantity, 0.2);
      expect(precision['BTCUSDT']?.formatPrice(100.056), '100.06');
    });
  });

  group('orders', () {
    test('a conditional order is accepted only when the algo reports NEW',
        () async {
      final client = StubClient({
        '/fapi/v1/algoOrder': [
          StubReply.json({'algoStatus': 'NEW'}),
          StubReply.json(
              {'algoStatus': 'REJECTED', 'msg': 'trigger below market'}),
        ],
      });
      final api = BinanceApi(client: client);

      expect(
          (await api.createTakeProfitOrder(
                  _keys, 'BTCUSDT', 'SELL', '0.2', '64500'))
              .accepted,
          isTrue);
      expect(
          (await api.createStopLossOrder(
                  _keys, 'BTCUSDT', 'SELL', '0.2', '63500'))
              .accepted,
          isFalse);
      expect(client.lastUrl.queryParameters['workingType'], 'MARK_PRICE');
      expect(client.urlAt(0).queryParameters['reduceOnly'], 'true');
    });

    test('a market order reports its exchange status', () async {
      final client = StubClient({
        '/fapi/v1/order': [
          StubReply.json({'status': 'FILLED', 'msg': ''}),
          StubReply('{"code":400,"msg":"notional too low"}', statusCode: 400),
        ],
      });
      final api = BinanceApi(client: client);

      expect(
          (await api.createFuturesMarketOrder(_keys, 'BTCUSDT', 'BUY', '0.2'))
              .accepted,
          isTrue);
      expect(
          (await api.createFuturesMarketOrder(_keys, 'BTCUSDT', 'BUY', '0.001'))
              .accepted,
          isFalse);
    });

    test('canceling reads the exchange status', () async {
      final client = StubClient({
        '/fapi/v1/order': [
          StubReply.json({'status': 'CANCELED'})
        ],
        '/fapi/v1/allOpenOrders': [
          StubReply.json({'code': 200, 'msg': ''})
        ],
      });
      final api = BinanceApi(client: client);

      expect((await api.cancelOrder(_keys, '5', 'BTCUSDT')).accepted, isTrue);
      expect((await api.cancelAllOrders(_keys, 'BTCUSDT')).accepted, isTrue);
    });

    test('a failed cancel is reported as rejected, not thrown', () async {
      final client = StubClient({
        '/fapi/v1/allOpenOrders': [StubReply('boom', statusCode: 500)],
      });

      final outcome =
          await BinanceApi(client: client).cancelAllOrders(_keys, 'BTCUSDT');

      expect(outcome.accepted, isFalse);
      expect(outcome.message, contains('could not be canceled'));
    });
  });

  group('trade history', () {
    test('fetches a long range in windows of seven days', () async {
      final client = StubClient({
        '/fapi/v1/userTrades': [
          StubReply.json([
            {
              'orderId': 1,
              'symbol': 'BTCUSDT',
              'side': 'BUY',
              'qty': '1',
              'realizedPnl': '0',
              'price': '100',
              'quoteQty': '100',
              'commission': '0.1',
              'commissionAsset': 'USDT',
              'time': 1000
            }
          ]),
          StubReply.json([
            {
              'orderId': 2,
              'symbol': 'BTCUSDT',
              'side': 'SELL',
              'qty': '1',
              'realizedPnl': '5',
              'price': '105',
              'quoteQty': '105',
              'commission': '0.1',
              'commissionAsset': 'USDT',
              'time': 2000
            }
          ]),
        ],
      });

      final start = DateTime.fromMillisecondsSinceEpoch(0);
      final end = start.add(const Duration(days: 9));

      final fills =
          await BinanceApi(client: client).getUserTrades(_keys, start, end);

      expect(client.requests.length, 2);
      expect(client.urlAt(0).queryParameters['endTime'],
          '${start.add(const Duration(days: 7)).millisecondsSinceEpoch}');
      expect(client.lastUrl.queryParameters['endTime'],
          '${end.millisecondsSinceEpoch}');
      expect(fills.length, 2);
    });

    test('a window that fails still returns the rest', () async {
      final client = StubClient({
        '/fapi/v1/userTrades': [
          StubReply('rate limited', statusCode: 429),
          StubReply.json([
            {
              'orderId': 2,
              'symbol': 'BTCUSDT',
              'side': 'SELL',
              'qty': '1',
              'realizedPnl': '5',
              'price': '105',
              'quoteQty': '105',
              'commission': '0.1',
              'commissionAsset': 'USDT',
              'time': 2000
            }
          ]),
        ],
      });

      final fills = await BinanceApi(client: client).getUserTrades(
        _keys,
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(0).add(const Duration(days: 9)),
      );

      expect(fills.length, 1);
    });
  });
}
