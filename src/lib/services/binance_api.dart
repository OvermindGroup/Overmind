import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
// import 'dart:io';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:uuid/uuid.dart';

class BinanceApi {
  final String baseUrl = 'https://api3.binance.com';
  final String futuresBaseUrl = 'https://fapi.binance.com';
  final String wsBaseUrl = 'wss://fstream.binance.com/ws';
  final String wsFapiBaseUrl = 'wss://ws-fapi.binance.com/ws-fapi/v1';

  Future<List<dynamic>> getUserAsset(String apiKey, String secretKey) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'timestamp': now.toString(),
        'needBtcValuation': 'true'
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/sapi/v3/asset/getUserAsset';
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load user asset data');
      }
    } catch (error) {
      print('Error fetching user asset data: $error');
      return [];
    }
  }

  Future<Map<String, double>> getPrices(List<String> instruments) async {
    if (instruments.isEmpty) {
      return {};
    }

    final String endpoint = '/api/v3/ticker/price';
    String url = '$baseUrl$endpoint';

    // If there is only one instrument
    if (instruments.length == 1) {
      url += '?symbol=${instruments.first}';
    } else {
      // Handle multiple instruments
      String symbolsParam = instruments.map((e) => '"$e"').join(',');
      url += '?symbols=[$symbolsParam]';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dynamic jsonData;

      try {
        jsonData = jsonDecode(response.body);
      } catch (e) {
        // Handle JSON decode error
        return {};
      }

      // Check if the response is an array of prices
      if (jsonData is List) {
        // Map each symbol and price to a key-value pair
        return {
          for (var item in jsonData)
          item['symbol'] as String: double.tryParse(item['price']) ?? 0.0
        };
      } else if (jsonData is Map<String, dynamic>) {
        // If the response is a single object
        return {
          jsonData['symbol'] as String: double.tryParse(jsonData['price']) ?? 0.0,
        };
      }
    }

    // Return empty map if the response is not successful
    return {};
  }

  Future<Map<String, dynamic>> getUserBalance(String apiKey, String secretKey, String quoteSymbol) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'timestamp': now.toString()
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v2/balance';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final balances = jsonDecode(response.body);
        final quoteBalance = balances.where((elt) => elt["asset"] == quoteSymbol).toList().first;
        return quoteBalance;
      } else {
        throw Exception('Failed to fetch user balance');
      }
    } catch (error) {
      print('Error fetching user balance: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> changeLeverage(String apiKey, String secretKey, String symbol, int leverage) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = {
      'leverage': leverage.toString(),
      'symbol': symbol,
      'timestamp': now.toString(),
    };

    final signature = createBinanceSignature(secretKey, params);
    params['signature'] = signature;

    final String endpoint = '/fapi/v1/leverage';
    final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
    final headers = {
      'X-MBX-APIKEY': apiKey,
    };

    final response = await http.post(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to change leverage: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getUserTrades(String apiKey, String secretKey, DateTime startDate, DateTime endDate) async {
    final List<Map<String, dynamic>> allTrades = [];
    final Duration maxTimeWindow = Duration(days: 7);
    DateTime currentStartDate = startDate;

    while (currentStartDate.isBefore(endDate)) {
      try {
        // Calculate end date for current chunk
        DateTime chunkEndDate = currentStartDate.add(maxTimeWindow);
        // If chunk end date is after the desired end date, use the desired end date
        if (chunkEndDate.isAfter(endDate)) {
          chunkEndDate = endDate;
        }

        final int now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, String> params = {
          'timestamp': now.toString(),
          'startTime': currentStartDate.millisecondsSinceEpoch.toString(),
          'endTime': chunkEndDate.millisecondsSinceEpoch.toString(),
        };

        final String signature = createBinanceSignature(secretKey, params);
        params['signature'] = signature;
        final String endpoint = '/fapi/v1/userTrades';
        final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
        final headers = {
          'X-MBX-APIKEY': apiKey,
        };

        final http.Response response = await http.get(url, headers: headers);

        if (response.statusCode == 200) {
          final List<dynamic> jsonResponse = jsonDecode(response.body);
          allTrades.addAll(jsonResponse.cast<Map<String, dynamic>>());

          // Add delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 100));
        } else {
          print('Error for period ${currentStartDate} to ${chunkEndDate}: ${jsonDecode(response.body)}');
          throw Exception('Failed to fetch user trades');
        }

        // Move to next chunk
        currentStartDate = chunkEndDate;
      } catch (error) {
        print('Error fetching user trades for period ${currentStartDate}: $error');
        // Continue to next chunk even if current one fails
        currentStartDate = currentStartDate.add(maxTimeWindow);
      }
    }

    return allTrades;
  }

  Future<Map<String, dynamic>> cancelOrder(String apiKey, String secretKey, String orderId, String symbol) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'orderId': orderId,
        'symbol': symbol,
        'timestamp': now.toString(),
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v1/order';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to cancel order');
      }
    } catch (error) {
      print('Error canceling order: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> cancelAllOrders(String apiKey, String secretKey, String symbol) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'symbol': symbol,
        'timestamp': now.toString(),
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v1/allOpenOrders';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to cancel orders for symbol $symbol');
      }
    } catch (error) {
      print('Error canceling orders for symbol $symbol: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> _createFuturesStopOrder(
    String apiKey,
    String secretKey,
    String symbol,
    String side,
    String quantity,
    String stopPrice,
    String type) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = {
      'symbol': symbol,
      'side': side,
      'quantity': quantity,
      'type': type,
      'stopPrice': stopPrice,
      'reduceOnly': 'true',
      'timestamp': now.toString(),
    };

    final signature = createBinanceSignature(secretKey, params);
    params['signature'] = signature;

    final String endpoint = '/fapi/v1/order';
    final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
    final headers = {
      'X-MBX-APIKEY': apiKey,
    };

    final response = await http.post(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create futures stop order $type $side $symbol $quantity $stopPrice: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createTakeProfitOrder(String binanceApiKey,
    String binanceSecretKey,
    String symbol,
    String side,
    String quantity,
    String stopPrice) async {
    return _createFuturesStopOrder(binanceApiKey, binanceSecretKey, symbol, side, quantity, stopPrice, "TAKE_PROFIT_MARKET");
  }

  Future<Map<String, dynamic>> createStopLossOrder(String binanceApiKey,
    String binanceSecretKey,
    String symbol,
    String side,
    String quantity,
    String stopPrice) async {
    return _createFuturesStopOrder(binanceApiKey, binanceSecretKey, symbol, side, quantity, stopPrice, "STOP_MARKET");
  }

  Future<Map<String, dynamic>> createFuturesMarketOrder(
    String apiKey,
    String secretKey,
    String symbol,
    String side,
    String quantity) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = {
      'symbol': symbol,
      'side': side,
      'quantity': quantity,
      'type': 'MARKET',
      'timestamp': now.toString(),
    };

    final signature = createBinanceSignature(secretKey, params);
    params['signature'] = signature;

    final String endpoint = '/fapi/v1/order';
    final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
    final headers = {
      'X-MBX-APIKEY': apiKey,
    };

    final response = await http.post(url, headers: headers);
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getUserOpenPositionsBySymbol(String apiKey, String secretKey, String symbol) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'symbol': symbol,
        'timestamp': now.toString(),
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v3/positionRisk';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final positions = jsonDecode(response.body);
        return positions;
      } else {
        throw Exception('Failed to fetch open positions');
      }
    } catch (error) {
      print('Error fetching open positions: $error');
      return [];
    }
  }

  Future<String> _getListenKey(String apiKey, String secretKey) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> params = {
      'timestamp': now.toString(),
    };
    final String signature = createBinanceSignature(secretKey, params);
    params['signature'] = signature;

    final String endpoint = '/fapi/v1/listenKey';
    final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
    final headers = {
      'X-MBX-APIKEY': apiKey,
    };

    final http.Response response = await http.post(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['listenKey'];
    } else {
      throw Exception('Failed to get listenKey: ${response.body}');
    }
  }

  Future<void> _keepAliveListenKey(String apiKey, String secretKey, String listenKey) async {
    while (true) {
      try {
        await Future.delayed(const Duration(minutes: 30));
        final int now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, String> params = {
          'listenKey': listenKey,
          'timestamp': now.toString(),
        };
        final String signature = createBinanceSignature(secretKey, params);
        params['signature'] = signature;

        final String endpoint = '/fapi/v1/listenKey';
        final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');

        final headers = {
          'X-MBX-APIKEY': apiKey,
        };

        final http.Response response = await http.put(url, headers: headers);
        if (response.statusCode != 200) {
          print('Failed to keep alive listenKey');
        }
      } catch (error) {
        print('Error keeping listenKey alive: $error');
        await Future.delayed(const Duration(minutes: 5)); // Attempt after 5 minutes if error
      }
    }
  }

  // Stream<List<dynamic>> getUserOpenPositionsWS(String apiKey, String secretKey) async* {
  //   WebSocketChannel? channel;
  //   String? listenKey;

  //   try {
  //     final int now = DateTime.now().millisecondsSinceEpoch;
  //     listenKey = await _getListenKey(apiKey, secretKey);
  //     final wsUrl = '$wsBaseUrl/$listenKey';

  //     final Map<String, dynamic> params = {
  //       'timestamp': now,
  //       'apiKey': apiKey
  //     };

  //     final String signature = createBinanceSignature(secretKey, params);
  //     params['signature'] = signature;

  //     final Map<String, String> request = {
  //       'id': Uuid().v4(),
  //       'method': 'v2/account.position',
  //       'params': jsonEncode(params)
  //     };

  //     // final socket = await WebSocket.connect(wsUrl);
  //     // final socket = await WebSocket.connect(wsFapiBaseUrl);

  //     channel = WebSocketChannel.connect(Uri.parse(wsFapiBaseUrl));
  //     channel.sink.add(jsonEncode(request));

  //     await for (final message in channel.stream) {
  //       print(message);
  //       // if(message is String) {
  //       //   final decodedMessage = jsonDecode(message);
  //       //   if(decodedMessage is Map && decodedMessage["data"] is List) {
  //       //     yield decodedMessage["data"];
  //       //   }
  //       // }
  //     }

  //   } catch (error) {
  //     print('Error establishing connection: $error');
  //     yield [];
  //   } finally {
  //     await channel?.sink.close();
  //     print('Websocket Connection Closed');
  //   }
  // }

  Future<List<dynamic>> getUserOpenPositions(String apiKey, String secretKey) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      final Map<String, String> params = {
        'timestamp': now.toString(),
      };

      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v3/positionRisk';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final positions = jsonDecode(response.body);
        return positions;
      } else {
        throw Exception('Failed to fetch open positions');
      }
    } catch (error) {
      print('Error fetching open positions: $error');
      return [];
    }
  }

  Future<List<dynamic>> getUserOpenOrders(String apiKey, String secretKey, String instrument) async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;

      // Set up the query parameters
      final Map<String, String> params = {
        'symbol': instrument,
        'timestamp': now.toString(),
      };

      // Generate signature
      final String signature = createBinanceSignature(secretKey, params);
      params['signature'] = signature;

      final String endpoint = '/fapi/v1/openOrders';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint${Uri(queryParameters: params)}');
      final headers = {
        'X-MBX-APIKEY': apiKey,
      };

      // Make the HTTP GET request
      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> orders = jsonDecode(response.body);
        return orders;
      } else {
        throw Exception('Failed to fetch open orders');
      }
    } catch (error) {
      print('Error fetching open orders: $error');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExchangeInfo(List<String> symbols) async {
    try {
      final String endpoint = '/fapi/v1/exchangeInfo';
      final Uri url = Uri.parse('$futuresBaseUrl$endpoint');

      final http.Response response = await http.get(url);

      if (response.statusCode == 200) {
        final fullInfo = jsonDecode(response.body);
        final symbolsInfo = List<Map<String, dynamic>>.from(fullInfo["symbols"]);
        final filtered = symbolsInfo.where((elt) => symbols.contains(elt["symbol"])).toList();
        return filtered;
      } else {
        throw Exception('Failed to fetch exchange info');
      }
    } catch (error) {
      print('Error fetching exchange info: $error');
      return [];
    }
  }

  Future<Map<String, Map<String, dynamic>>> futuresMinimumQuantities(List<String> instruments) async {
    final prices = await getPrices(instruments);
    final exchangeInfo = await getExchangeInfo(instruments);

    final result = <String, Map<String, dynamic>>{};

    for (var info in exchangeInfo) {
      final symbol = info['symbol'];

      // Extract filters
      final tickSize = double.parse(
        (info['filters'] as List)
        .firstWhere((filter) => filter['filterType'] == 'PRICE_FILTER')['tickSize']
      );

      final notional = double.parse(
        (info['filters'] as List)
        .firstWhere((filter) => filter['filterType'] == 'MIN_NOTIONAL')['notional']
      );

      final lotInfo = (info['filters'] as List)
      .firstWhere((filter) => filter['filterType'] == 'LOT_SIZE');

      final stepSize = double.parse(lotInfo['stepSize']);
      final minQuantity = double.parse(lotInfo['minQty']);

      final price = prices[symbol] ?? 0.0;

      final baseMinQuantity = max((notional / price / stepSize).ceil() * stepSize, minQuantity);
      final quoteMinQuantity = (baseMinQuantity * price / tickSize).ceil() * tickSize;

      result[symbol] = {
        'quantityPrecision': info['quantityPrecision'],
        'pricePrecision': info['pricePrecision'],
        'minQuantity': quoteMinQuantity.toStringAsFixed(info['quantityPrecision']),
      };
    }

    return result;
  }

  String createBinanceSignature(String secretKey, Map<String, String> params) {
    final String queryString = Uri(queryParameters: params).query;
    final hmacSha256 = Hmac(sha256, utf8.encode(secretKey));
    final Digest digest = hmacSha256.convert(utf8.encode(queryString));
    return digest.toString();
  }
}
