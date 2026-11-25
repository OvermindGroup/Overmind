import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/services/overmind_api.dart';

import '../stub_http_client.dart';

const String _apiKey = 'test-key';

void main() {
  group('portfolio reads', () {
    test('parses the signals the server returns', () async {
      final client = StubClient({
        '/v1/models/1/outputs': [
          StubReply.json([
            {
              'instrument': 'BTCUSDT',
              'timeframe': '5m',
              'takeProfit': 120,
              'stopLoss': -60,
              'outputScore': 0.85
            },
            {
              'instrument': 'ETHUSDT',
              'timeframe': '30m',
              'takeProfit': -30,
              'stopLoss': 15,
              'outputScore': 0.62
            },
          ]),
        ],
      });

      final portfolio = await OvermindApi(client: client).getPortfolio(_apiKey);

      expect(portfolio.length, 2);
      expect(portfolio.holdings.first.takeProfit, 120);
      expect(client.requests.single.headers, contains('Authorization'));
    });

    test('a server failure surfaces instead of showing an empty dashboard',
        () async {
      final client = StubClient({
        '/v1/models/1/outputs': [StubReply('down', statusCode: 503)],
      });

      await expectLater(
        OvermindApi(client: client).getPortfolio(_apiKey),
        throwsA(isA<OvermindException>()),
      );
    });

    test('symbols come from the crypto list', () async {
      final client = StubClient({
        '/v1/meta/symbols': [
          StubReply.json({
            'crypto': ['BTCUSDT', 'ETHUSDT']
          })
        ],
      });

      expect(await OvermindApi(client: client).getSymbols(_apiKey),
          ['BTCUSDT', 'ETHUSDT']);
    });
  });

  group('training and reset', () {
    test('training posts the requested parameters', () async {
      final client = StubClient({
        '/v1/models/1/train': [StubReply.json([])],
      });

      await OvermindApi(client: client).trainPortfolio(
        _apiKey,
        const TrainingRequest(
          iterations: 40,
          maxTradeHorizon: 200,
          takeProfitPercentage: 0.08,
          stopLossPercentage: 0.04,
        ),
      );

      expect(client.requests.single.method, 'POST');
      expect(client.bodyAt(0), contains('"maxTradeHorizon":200'));
      expect(client.bodyAt(0), contains('"tpPercentage":0.08'));
    });

    test('training a subset sends the symbols as a query', () async {
      final client = StubClient({
        '/v1/models/1/train': [
          StubReply.json([
            {
              'instrument': 'BTCUSDT',
              'timeframe': '5m',
              'outputScore': 0.9,
              'tpLower': 1,
              'tpUpper': 5,
              'takeProfit': 1,
              'direction1': 0.9,
              'direction2': -0.9
            }
          ])
        ],
      });

      final portfolio = await OvermindApi(client: client).trainSymbols(
        _apiKey,
        const TrainingRequest(
            iterations: 1,
            maxTradeHorizon: 10,
            takeProfitPercentage: 1,
            stopLossPercentage: 1),
        ['BTCUSDT', 'ETHUSDT'],
      );

      expect(client.lastUrl.queryParameters['symbols'], 'BTCUSDT,ETHUSDT');
      expect(portfolio.length, 1);
    });

    test('a failed training run degrades to an unchanged portfolio', () async {
      final client = StubClient({
        '/v1/models/1/train': [StubReply('queue full', statusCode: 500)],
      });

      final portfolio = await OvermindApi(client: client).trainPortfolio(
        _apiKey,
        const TrainingRequest(
            iterations: 1,
            maxTradeHorizon: 10,
            takeProfitPercentage: 1,
            stopLossPercentage: 1),
      );

      expect(portfolio.isEmpty, isTrue);
    });

    test('resetting a model names the instrument', () async {
      final client = StubClient({
        '/v1/models/1/reset': [StubReply.json([])],
      });

      await OvermindApi(client: client).resetModel(_apiKey, 'BTCUSDT');

      expect(client.lastUrl.queryParameters['instrument'], 'BTCUSDT');
    });

    test('resetting several models names them all', () async {
      final client = StubClient({
        '/v1/models/1/reset': [StubReply.json([])],
      });

      await OvermindApi(client: client)
          .resetModels(_apiKey, ['BTCUSDT', 'ETHUSDT']);

      expect(client.lastUrl.queryParameters['instruments'], 'BTCUSDT,ETHUSDT');
    });
  });

  group('queue', () {
    test('reports whether a run is queued', () async {
      final client = StubClient({
        '/v1/models': [
          StubReply.json({'inQueue': true}),
          StubReply.json({'inQueue': false}),
        ],
      });
      final api = OvermindApi(client: client);

      expect(await api.isTrainInQueue(_apiKey), isTrue);
      expect(await api.isTrainInQueue(_apiKey), isFalse);
    });

    test('an unreadable queue is treated as empty', () async {
      final client = StubClient({
        '/v1/models': [StubReply('down', statusCode: 500)],
      });

      expect(
          await OvermindApi(client: client).isTrainInQueue(_apiKey), isFalse);
    });
  });

  group('prices', () {
    test('the latest price is the close', () async {
      final client = StubClient({
        '/v1/meta/latestPrice': [
          StubReply.json({'close': '64000.5'})
        ],
      });

      expect(
          await OvermindApi(client: client).getLatestPrice(_apiKey, 'BTCUSDT'),
          64000.5);
    });

    // Regression: a failed price read used to return an empty map, and the
    // trader then placed orders around a price of zero.
    test('a missing price stops a trade instead of silently using zero',
        () async {
      final client = StubClient({
        '/v1/meta/latestPrice': [StubReply('down', statusCode: 500)],
      });

      await expectLater(
        OvermindApi(client: client).getLatestPrice(_apiKey, 'BTCUSDT'),
        throwsA(isA<OvermindException>()),
      );
    });

    test('many prices are read in one call and nothing is asked for no symbols',
        () async {
      final client = StubClient({
        '/v1/meta/latestPrices': [
          StubReply.json({'BTCUSDT': '64000', 'ETHUSDT': '3000'})
        ],
      });
      final api = OvermindApi(client: client);

      expect(await api.getLatestPrices(_apiKey, ['BTCUSDT', 'ETHUSDT']), {
        'BTCUSDT': 64000,
        'ETHUSDT': 3000,
      });
      expect(await api.getLatestPrices(_apiKey, const []), isEmpty);
      expect(client.requests.length, 1);
    });
  });

  group('indicator series', () {
    test('reads the candle series and its scaling height', () async {
      final client = StubClient({
        '/v1/indicators/amherag': [
          StubReply.json({
            'height': 1.5,
            'candles': [
              {
                'candle': {
                  'date': 1700000000000,
                  'open': 100,
                  'high': 110,
                  'low': 95,
                  'close': 105,
                  'volume': 12
                },
                'above': [1, 2],
                'below': [0.5],
                'max': 110,
                'min': 95,
              },
            ],
          }),
        ],
      });

      final data = await OvermindApi(client: client)
          .getAmherag(_apiKey, 'BTCUSDT', '5m');

      expect(data.height, 1.5);
      expect(data.candles.single.timestamp, 1700000000000);
      expect(data.candles.single.close, 105);
      expect(data.candles.single.above, [1, 2]);
      expect(client.lastUrl.queryParameters['timeframe'], '5m');
    });
  });

  group('free-tier key', () {
    test('returns the key the server issues', () async {
      final client = StubClient({
        '/v1/auth/token/free': [StubReply(' free-key \n')],
      });

      expect(await OvermindApi(client: client).getFreeTierApiKey(), 'free-key');
    });

    // Regression: a failure used to return an empty key, which was then stored
    // and reported as success.
    test('a failure is reported rather than stored as an empty key', () async {
      final client = StubClient({
        '/v1/auth/token/free': [StubReply('rate limited', statusCode: 429)],
      });

      await expectLater(
        OvermindApi(client: client).getFreeTierApiKey(),
        throwsA(isA<OvermindException>()),
      );
    });
  });
}
