import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/market_data.dart';
import '../domain/portfolio.dart';
import '../utils/log.dart';

/// A failed Overmind server request.
class OvermindException implements Exception {
  const OvermindException(this.endpoint, this.statusCode, this.body);

  final String endpoint;
  final int statusCode;
  final String body;

  @override
  String toString() => 'Overmind $endpoint failed ($statusCode): $body';
}

/// Parameters for a training run.
class TrainingRequest {
  const TrainingRequest({
    required this.iterations,
    required this.maxTradeHorizon,
    required this.takeProfitPercentage,
    required this.stopLossPercentage,
  });

  final int iterations;
  final int maxTradeHorizon;
  final double takeProfitPercentage;
  final double stopLossPercentage;

  Map<String, dynamic> toJson() => {
        'iterations': iterations,
        'maxTradeHorizon': maxTradeHorizon,
        'tpPercentage': takeProfitPercentage,
        'slPercentage': stopLossPercentage,
      };

  Map<String, String> toQuery() => {
        'iterations': iterations.toString(),
        'maxTradeHorizon': maxTradeHorizon.toString(),
        'tpPercentage': takeProfitPercentage.toString(),
        'slPercentage': stopLossPercentage.toString(),
      };
}

/// Client for the Overmind model server.
///
/// Reads that the UI cannot degrade (portfolio, symbols, candles, prices) throw;
/// actions that can fail without breaking the dashboard (train, reset, queue
/// checks) log and return an empty result, matching the previous behaviour.
class OvermindApi {
  OvermindApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
    String environment = defaultEnvironment,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _environment = environment;

  /// LAN address of the author's dev server. Override this for a deployment by
  /// constructing the client with [baseUrl].
  static const String defaultBaseUrl = 'http://172.20.23.250:1989';
  static const String defaultEnvironment = '1';

  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;
  final String _baseUrl;
  final String _environment;

  /// Everything the user has been trained on, including signals that are not
  /// tradable. Throws so a stale dashboard is reported instead of shown empty.
  Future<Portfolio> getPortfolio(String apiKey) async {
    final decoded =
        await _request('GET', '$_modelsPath/outputs', apiKey: apiKey);
    return Portfolio.fromJson(_asList(decoded));
  }

  Future<Portfolio> trainPortfolio(
      String apiKey, TrainingRequest request) async {
    return _swallow(
      'training portfolio',
      () async {
        final decoded = await _request(
          'POST',
          '$_modelsPath/train',
          apiKey: apiKey,
          body: jsonEncode(request.toJson()),
        );
        return Portfolio.fromJson(_asList(decoded));
      },
      Portfolio.empty,
    );
  }

  Future<Portfolio> trainSymbols(
    String apiKey,
    TrainingRequest request,
    List<String> symbols,
  ) async {
    return _swallow(
      'training models for ${symbols.join(',')}',
      () async {
        final decoded = await _request(
          'GET',
          '$_modelsPath/train',
          apiKey: apiKey,
          params: {...request.toQuery(), 'symbols': symbols.join(',')},
        );
        return Portfolio.fromJson(_asList(decoded));
      },
      Portfolio.empty,
    );
  }

  Future<Portfolio> resetPortfolio(String apiKey) async {
    return _swallow(
      'resetting portfolio',
      () async => Portfolio.fromJson(
        _asList(await _request('POST', '$_modelsPath/reset', apiKey: apiKey)),
      ),
      Portfolio.empty,
    );
  }

  Future<Portfolio> resetModel(String apiKey, String symbol) async {
    return _swallow(
      'resetting model for $symbol',
      () async => Portfolio.fromJson(_asList(await _request(
        'POST',
        '$_modelsPath/reset',
        apiKey: apiKey,
        params: {'instrument': symbol},
      ))),
      Portfolio.empty,
    );
  }

  Future<Portfolio> resetModels(String apiKey, List<String> symbols) async {
    return _swallow(
      'resetting models for ${symbols.join(',')}',
      () async => Portfolio.fromJson(_asList(await _request(
        'POST',
        '$_modelsPath/reset',
        apiKey: apiKey,
        params: {'instruments': symbols.join(',')},
      ))),
      Portfolio.empty,
    );
  }

  /// Symbols the server can trade. Throws so the symbol dropdown shows a real
  /// failure instead of silently offering nothing.
  Future<List<String>> getSymbols(String apiKey) async {
    final decoded =
        _asMap(await _request('GET', '/v1/meta/symbols', apiKey: apiKey));
    return _asList(decoded['crypto'])
        .map((symbol) => symbol.toString())
        .toList();
  }

  /// Whether a training run is already queued. Degrades to false: the worst
  /// outcome is a duplicate request, not a blocked dashboard.
  Future<bool> isTrainInQueue(String apiKey) async {
    return _swallow(
      'checking the training queue',
      () async {
        final decoded =
            _asMap(await _request('GET', '/v1/models', apiKey: apiKey));
        return decoded['inQueue'] == true;
      },
      false,
    );
  }

  Future<AmheragData> getAmherag(
      String apiKey, String symbol, String timeframe) async {
    final decoded = _asMap(await _request(
      'GET',
      '/v1/indicators/amherag',
      apiKey: apiKey,
      params: {'symbol': symbol, 'timeframe': timeframe},
    ));
    return AmheragData.fromApi(decoded);
  }

  /// Close of the newest candle. Throws when unavailable: trading on a price of
  /// zero would place orders with meaningless take-profit and stop-loss levels.
  Future<double> getLatestPrice(String apiKey, String symbol) async {
    final decoded = _asMap(await _request(
      'GET',
      '/v1/meta/latestPrice',
      apiKey: apiKey,
      params: {'symbol': symbol},
    ));
    return _asDouble(decoded['close']);
  }

  Future<Map<String, double>> getLatestPrices(
    String apiKey,
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final decoded = _asMap(await _request(
      'GET',
      '/v1/meta/latestPrices',
      apiKey: apiKey,
      params: {'symbol': symbols.join(',')},
    ));
    return decoded.map((key, value) => MapEntry(key, _asDouble(value)));
  }

  /// A free-tier key. Throws on failure so the API-key modal can tell the user
  /// it did not work instead of storing an empty key.
  Future<String> getFreeTierApiKey() async {
    final response = await _send('GET', '/v1/auth/token/free');
    if (response.statusCode != 200) {
      throw OvermindException(
          '/v1/auth/token/free', response.statusCode, response.body);
    }
    return response.body.trim();
  }

  String get _modelsPath => '/v1/models/$_environment';

  Future<dynamic> _request(
    String method,
    String endpoint, {
    String? apiKey,
    Map<String, String>? params,
    String? body,
  }) async {
    final response = await _send(method, endpoint,
        apiKey: apiKey, params: params, body: body);
    if (response.statusCode != 200) {
      throw OvermindException(endpoint, response.statusCode, response.body);
    }
    return jsonDecode(response.body);
  }

  Future<http.Response> _send(
    String method,
    String endpoint, {
    String? apiKey,
    Map<String, String>? params,
    String? body,
  }) async {
    final url =
        Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
    final request = http.Request(method, url);
    if (apiKey != null) request.headers['Authorization'] = 'Bearer $apiKey';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = body;
    }
    final streamed = await _client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }
}

Future<T> _swallow<T>(
    String context, Future<T> Function() read, T fallback) async {
  try {
    return await read();
  } catch (error) {
    logError(context, error);
    return fallback;
  }
}

List<dynamic> _asList(Object? value) => value is List ? value : const [];

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;
