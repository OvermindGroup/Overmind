import 'dart:convert';
import 'dart:math' show max;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/account_balance.dart';
import '../domain/api_keys.dart';
import '../domain/exchange.dart';
import '../domain/market_data.dart';
import '../domain/trades.dart';
import '../utils/log.dart';

/// A Binance request that did not return what we asked for.
class BinanceException implements Exception {
  const BinanceException(this.endpoint, this.statusCode, this.body);

  final String endpoint;
  final int statusCode;
  final String body;

  @override
  String toString() => 'Binance $endpoint failed ($statusCode): $body';
}

/// Binance spot and USDT-M futures endpoints.
///
/// Requests are built through [_request], which owns signing, headers and the
/// timeout, so each method only describes the endpoint and its parameters.
/// Injecting [client] makes the whole class testable without the network.
class BinanceApi {
  BinanceApi({
    http.Client? client,
    String spotBaseUrl = defaultSpotBaseUrl,
    String futuresBaseUrl = defaultFuturesBaseUrl,
  })  : _client = client ?? http.Client(),
        _spotBaseUrl = spotBaseUrl,
        _futuresBaseUrl = futuresBaseUrl;

  static const String defaultSpotBaseUrl = 'https://api3.binance.com';
  static const String defaultFuturesBaseUrl = 'https://fapi.binance.com';

  static const Duration _timeout = Duration(seconds: 30);

  /// Binance rejects trade queries wider than this, so history is fetched in
  /// chunks and the pace is throttled to stay inside the rate limit.
  static const Duration _maxTradeWindow = Duration(days: 7);
  static const Duration _rateLimitDelay = Duration(milliseconds: 100);

  final http.Client _client;
  final String _spotBaseUrl;
  final String _futuresBaseUrl;

  /// Latest traded price per symbol (spot ticker).
  Future<Map<String, double>> getPrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    final decoded = await _request(
      'GET',
      _spotBaseUrl,
      '/api/v3/ticker/price',
      params: _symbolParams(symbols),
    );
    return _mapValues(decoded, (item) => _asDouble(item['price']));
  }

  /// Best bid/ask per symbol. Returns an empty map when the book is unreachable
  /// so a missing quote degrades to "no price" rather than failing the chart.
  Future<Map<String, BookPrice>> getBookPrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    return _swallow('fetching futures book prices', () async {
      final decoded = await _request(
        'GET',
        _futuresBaseUrl,
        '/fapi/v1/ticker/bookTicker',
        params: _symbolParams(symbols),
      );
      return _mapValues(decoded, BookPrice.fromApi);
    }, const <String, BookPrice>{});
  }

  /// Margin balance for [quoteSymbol].
  Future<FuturesBalance> getUserBalance(
      ApiKeys keys, String quoteSymbol) async {
    return _swallow('fetching user balance', () async {
      final decoded = await _request(
        'GET',
        _futuresBaseUrl,
        '/fapi/v2/balance',
        keys: keys,
      );
      final entry = _entries(decoded)
          .where((balance) => balance['asset'] == quoteSymbol)
          .firstOrNull;
      if (entry == null) {
        throw BinanceException(
            '/fapi/v2/balance', 200, 'no $quoteSymbol balance');
      }
      return FuturesBalance.fromApi(entry);
    }, FuturesBalance.empty);
  }

  Future<void> changeLeverage(ApiKeys keys, String symbol, int leverage) async {
    await _request(
      'POST',
      _futuresBaseUrl,
      '/fapi/v1/leverage',
      params: {'symbol': symbol, 'leverage': leverage.toString()},
      keys: keys,
    );
  }

  /// Every fill in [start, end], fetched in windows of [_maxTradeWindow].
  ///
  /// A failing window is skipped rather than aborting the whole history, so a
  /// single bad chunk still leaves the rest of the month readable.
  Future<List<TradeFill>> getUserTrades(
    ApiKeys keys,
    DateTime start,
    DateTime end,
  ) async {
    final fills = <TradeFill>[];
    var chunkStart = start;

    while (chunkStart.isBefore(end)) {
      final chunkEnd = chunkStart.add(_maxTradeWindow);
      final windowEnd = chunkEnd.isAfter(end) ? end : chunkEnd;

      try {
        final decoded = await _request(
          'GET',
          _futuresBaseUrl,
          '/fapi/v1/userTrades',
          params: {
            'startTime': chunkStart.millisecondsSinceEpoch.toString(),
            'endTime': windowEnd.millisecondsSinceEpoch.toString(),
          },
          keys: keys,
        );
        fills.addAll(_entries(decoded).map(TradeFill.fromApi));
        await Future.delayed(_rateLimitDelay);
        chunkStart = windowEnd;
      } catch (error) {
        logError(
            'fetching trades ${chunkStart.toIso8601String()}..${windowEnd.toIso8601String()}',
            error);
        chunkStart = windowEnd;
      }
    }

    return fills;
  }

  /// Positions with a non-zero amount. Flat rows are excluded: they would count
  /// as open trades and stop the auto trader from opening real ones.
  Future<List<OpenPosition>> getUserOpenPositions(ApiKeys keys) async {
    return _swallow('fetching open positions', () async {
      final decoded = await _request(
        'GET',
        _futuresBaseUrl,
        '/fapi/v3/positionRisk',
        keys: keys,
      );
      return _positions(decoded);
    }, const <OpenPosition>[]);
  }

  Future<List<OpenPosition>> getUserOpenPositionsBySymbol(
    ApiKeys keys,
    String symbol,
  ) async {
    return _swallow('fetching open positions for $symbol', () async {
      final decoded = await _request(
        'GET',
        _futuresBaseUrl,
        '/fapi/v3/positionRisk',
        params: {'symbol': symbol},
        keys: keys,
      );
      return _positions(decoded);
    }, const <OpenPosition>[]);
  }

  Future<List<OpenOrder>> getUserOpenOrders(
    ApiKeys keys,
    String symbol,
  ) async {
    return _swallow('fetching open orders for $symbol', () async {
      final decoded = await _request(
        'GET',
        _futuresBaseUrl,
        '/fapi/v1/openAlgoOrders',
        params: {'symbol': symbol},
        keys: keys,
      );
      return _entries(decoded)
          .map(OpenOrder.tryFrom)
          .whereType<OpenOrder>()
          .toList();
    }, const <OpenOrder>[]);
  }

  Future<OrderOutcome> cancelOrder(
      ApiKeys keys, String orderId, String symbol) async {
    return _swallow('canceling order $orderId for $symbol', () async {
      final decoded = await _request(
        'DELETE',
        _futuresBaseUrl,
        '/fapi/v1/order',
        params: {'orderId': orderId, 'symbol': symbol},
        keys: keys,
      );
      return OrderOutcome.canceled(_asMap(decoded));
    }, OrderOutcome.rejected('order $orderId could not be canceled'));
  }

  Future<OrderOutcome> cancelAllOrders(ApiKeys keys, String symbol) async {
    return _swallow('canceling orders for $symbol', () async {
      final decoded = await _request(
        'DELETE',
        _futuresBaseUrl,
        '/fapi/v1/allOpenOrders',
        params: {'symbol': symbol},
        keys: keys,
      );
      return OrderOutcome.bulkCanceled(_asMap(decoded));
    }, OrderOutcome.rejected('orders for $symbol could not be canceled'));
  }

  Future<OrderOutcome> createTakeProfitOrder(
    ApiKeys keys,
    String symbol,
    String side,
    String quantity,
    String triggerPrice,
  ) =>
      _createConditionalOrder(
        keys,
        symbol,
        side,
        quantity,
        triggerPrice,
        'TAKE_PROFIT_MARKET',
      );

  Future<OrderOutcome> createStopLossOrder(
    ApiKeys keys,
    String symbol,
    String side,
    String quantity,
    String triggerPrice,
  ) =>
      _createConditionalOrder(
        keys,
        symbol,
        side,
        quantity,
        triggerPrice,
        'STOP_MARKET',
      );

  /// Open a or close a position at market. A non-200 response is reported as a
  /// rejection instead of throwing, because callers trade symbol by symbol and
  /// must keep going after one failure.
  Future<OrderOutcome> createFuturesMarketOrder(
    ApiKeys keys,
    String symbol,
    String side,
    String quantity,
  ) async {
    try {
      final response = await _send(
        'POST',
        _signedUrl(
            _futuresBaseUrl,
            '/fapi/v1/order',
            {
              'symbol': symbol,
              'side': side,
              'quantity': quantity,
              'type': 'MARKET',
            },
            keys),
        keys,
      );
      if (response.statusCode != 200) {
        return OrderOutcome.rejected(
            '${response.statusCode}: ${response.body}');
      }
      return OrderOutcome.created(_asMap(jsonDecode(response.body)));
    } catch (error) {
      logError('creating market order for $symbol', error);
      return OrderOutcome.rejected('market order for $symbol failed');
    }
  }

  /// Tick size, lot size and price/quantity precision for [symbols], plus the
  /// minimum quantity that satisfies the notional requirement at the current
  /// price.
  Future<Map<String, SymbolPrecision>> futuresMinimumQuantities(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final prices = await getPrices(symbols);
    final exchangeInfo = await _swallow(
      'fetching exchange info',
      () async {
        final decoded =
            await _request('GET', _futuresBaseUrl, '/fapi/v1/exchangeInfo');
        return _entries(decoded['symbols']);
      },
      const <Map<String, dynamic>>[],
    );

    final result = <String, SymbolPrecision>{};
    for (final info in exchangeInfo) {
      final symbol = info['symbol']?.toString() ?? '';
      final filters = _entries(info['filters']);

      final notional =
          _asDouble(_filterValue(filters, 'MIN_NOTIONAL', 'notional'));
      final stepSize = _asDouble(_filterValue(filters, 'LOT_SIZE', 'stepSize'));
      final minQuantity =
          _asDouble(_filterValue(filters, 'LOT_SIZE', 'minQty'));
      final quantityPrecision = _asInt(info['quantityPrecision']);

      final price = prices[symbol] ?? 0.0;
      final baseMinQuantity = price == 0
          ? minQuantity
          : max((notional / price / stepSize).ceil() * stepSize, minQuantity);

      result[symbol] = SymbolPrecision(
        pricePrecision: _asInt(info['pricePrecision']),
        quantityPrecision: quantityPrecision,
        minQuantity: baseMinQuantity,
        minNotional: notional,
      );
    }

    return result;
  }

  Future<OrderOutcome> _createConditionalOrder(
    ApiKeys keys,
    String symbol,
    String side,
    String quantity,
    String triggerPrice,
    String type,
  ) async {
    final decoded = await _request(
      'POST',
      _futuresBaseUrl,
      '/fapi/v1/algoOrder',
      params: {
        'symbol': symbol,
        'side': side,
        'quantity': quantity,
        'type': type,
        'triggerPrice': triggerPrice,
        'reduceOnly': 'true',
        'algoType': 'CONDITIONAL',
        'workingType': 'MARK_PRICE',
      },
      keys: keys,
    );
    return OrderOutcome.createdAlgo(_asMap(decoded));
  }

  /// Adds the timestamp and HMAC signature Binance requires for private calls.
  Uri _signedUrl(
    String base,
    String endpoint,
    Map<String, String> params,
    ApiKeys keys,
  ) {
    final query = <String, String>{
      ...params,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    query['signature'] = _signature(keys.binanceApiSecret, query);
    return Uri.parse('$base$endpoint').replace(queryParameters: query);
  }

  String _signature(String secretKey, Map<String, String> params) {
    final queryString = Uri(queryParameters: params).query;
    final digest =
        Hmac(sha256, utf8.encode(secretKey)).convert(utf8.encode(queryString));
    return digest.toString();
  }

  Future<dynamic> _request(
    String method,
    String base,
    String endpoint, {
    Map<String, String>? params,
    ApiKeys? keys,
  }) async {
    final url = keys == null
        ? Uri.parse('$base$endpoint').replace(queryParameters: params)
        : _signedUrl(base, endpoint, params ?? const {}, keys);

    final response = await _send(method, url, keys);
    if (response.statusCode != 200) {
      throw BinanceException(endpoint, response.statusCode, response.body);
    }
    return jsonDecode(response.body);
  }

  Future<http.Response> _send(String method, Uri url, ApiKeys? keys) async {
    final request = http.Request(method, url);
    if (keys != null) request.headers['X-MBX-APIKEY'] = keys.binanceApiKey;
    final streamed = await _client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }
}

/// Single-symbol queries use `symbol`, multi-symbol ones a JSON array.
Map<String, String> _symbolParams(List<String> symbols) {
  if (symbols.length == 1) return {'symbol': symbols.first};
  return {'symbols': jsonEncode(symbols)};
}

/// A failed read is reported and replaced by the caller's fallback, so one
/// unreachable endpoint never takes the dashboard down.
Future<T> _swallow<T>(
    String context, Future<T> Function() read, T fallback) async {
  try {
    return await read();
  } catch (error) {
    logError(context, error);
    return fallback;
  }
}

List<Map<String, dynamic>> _entries(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

List<OpenPosition> _positions(Object? decoded) => _entries(decoded)
    .map(OpenPosition.tryFrom)
    .whereType<OpenPosition>()
    .toList();

/// Normalizes a one-object or many-object ticker response into a keyed map.
Map<String, V> _mapValues<V>(
    Object? decoded, V Function(Map<String, dynamic>) parse) {
  if (decoded is Map<String, dynamic>) {
    final symbol = decoded['symbol']?.toString();
    return symbol == null ? {} : {symbol: parse(decoded)};
  }
  return {
    for (final item in _entries(decoded))
      item['symbol']?.toString() ?? '': parse(item),
  };
}

Object? _filterValue(
    List<Map<String, dynamic>> filters, String filterType, String key) {
  for (final filter in filters) {
    if (filter['filterType'] == filterType) return filter[key];
  }
  return null;
}

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
