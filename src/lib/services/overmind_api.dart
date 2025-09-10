import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' show max;
import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';

final player = AudioPlayer();

class Holding {
  final double takeProfit;
  final double stopLoss;
  final double riskReward;
  final int horizon;
  final double testingScore;
  final String instrument;
  final String timeframe;
  final String horizonFormatted;
  final double allocation;
  final double trainingScore;
  final double outputScore;
  final double outputDelta;
  final List<dynamic> lastTrades;
  final double tpVolPerc;
  final double slVolPerc;
  final double direction1;
  final double direction2;
  final double tpBig;
  final double tpWithin;

  Holding({
      required this.takeProfit,
      required this.stopLoss,
      required this.riskReward,
      required this.horizon,
      required this.testingScore,
      required this.instrument,
      required this.timeframe,
      required this.horizonFormatted,
      required this.allocation,
      required this.trainingScore,
      required this.outputScore,
      required this.outputDelta,
      required this.lastTrades,
      required this.tpVolPerc,
      required this.slVolPerc,
      required this.direction1,
      required this.direction2,
      required this.tpBig,
      required this.tpWithin,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      takeProfit: json['takeProfit'],
      stopLoss: json['stopLoss'],
      riskReward: json['riskReward'],
      horizon: json['horizon'].toInt(),
      testingScore: json['testingScore'].toDouble(),
      instrument: json['instrument'],
      timeframe: json['timeframe'],
      horizonFormatted: json['horizonFormatted'],
      allocation: json['allocation'].toDouble(),
      trainingScore: json['trainingScore'].toDouble(),
      outputScore: json['outputScore'].toDouble(),
      outputDelta: json['outputDelta'].toDouble(),
      lastTrades: json['lastTrades'].toList() as List<dynamic>,
      tpVolPerc: json['tpVolPerc'].toDouble(),
      slVolPerc: json['slVolPerc'].toDouble(),
      direction1: json['direction1'].toDouble(),
      direction2: json['direction2'].toDouble(),
      tpBig: json['tpBig'].toDouble(),
      tpWithin: json['tpWithin'].toDouble(),
    );
  }
}

class Portfolio {
  final List<Holding> holdings;
  
  // List<Holding> get holdings => _holdings;

  Portfolio({required this.holdings});

  factory Portfolio.fromJson(List<dynamic> json) {
    json.map((item) => print(item));
    List<Holding> holdings = json.map((item) => Holding.fromJson(item)).toList();
    return Portfolio(holdings: holdings);
  }

  double get totalAllocation {
    return holdings.fold(0, (sum, holding) => sum + holding.allocation);
  }

  List<String> get symbols {
    return holdings.map((holding) => holding.instrument).toList();
  }

  double get averageRiskReward {
    if (holdings.isEmpty) return 0;
    double total = holdings.fold(0, (sum, holding) => sum + holding.riskReward);
    return total / holdings.length;
  }

  Holding operator [](int index) {
    if (index < 0 || index >= holdings.length) {
      throw RangeError('Index out of bounds: $index');
    }
    return holdings[index];
  }

  Holding getHolding(String instrument, String timeframe) {
    return holdings.firstWhere(
      (holding) => holding.instrument == instrument && holding.timeframe == timeframe,
      // orElse: () => throw StateError('Instrument $instrument not found in portfolio'),
      orElse: () => Holding(
        takeProfit: 0.0,
        stopLoss: 0.0,
        riskReward: 0.0,
        horizon: 0,
        testingScore: 0.0,
        instrument: "",
        timeframe: "",
        horizonFormatted: "",
        allocation: 0.0,
        trainingScore: 0.0,
        outputScore: 0.0,
        outputDelta: 0.0,
        lastTrades: [],
        tpVolPerc: 0.0,
        slVolPerc: 0.0,
        direction1: 0.0,
        direction2: 0.0,
        tpBig: 0.0,
        tpWithin: 0.0,
      ),
      // orElse: () => Holding(),
    );
  }

  int get length => holdings.length;

  bool get isEmpty {
    return holdings.isEmpty;
  }

  // Portfolio map(Holding Function(Holding) f) {
  //   List<Holding> newHoldings = holdings.map(f).toList();
  //   return Portfolio(holdings: newHoldings);
  // }
  
  List<T> map<T>(T Function(Holding) f) {
    return holdings.map(f).toList();
  }

  void forEach(void Function(Holding) f) {
    holdings.forEach(f);
  }

  Portfolio where(bool Function(Holding) test) {
    List<Holding> newHoldings = holdings.where(test).toList();
    return Portfolio(holdings: newHoldings);
  }

  Portfolio filterByScores(
    double minRiskReward,
    double maxRiskReward,
    double minTestingScore,
    double minOutputScore,
    double minTpVolPerc,
    double minSlVolPerc
  ) {
    List<Holding> filteredHoldings = holdings.where((holding) {
        // Check if holding meets all the score criteria
        return holding.riskReward >= minRiskReward &&
        holding.riskReward <= maxRiskReward &&
        holding.testingScore >= minTestingScore &&
        holding.outputScore >= minOutputScore &&
        holding.tpVolPerc.abs() >= minTpVolPerc &&
        holding.slVolPerc.abs() >= minSlVolPerc;
    }).toList();

    // Return a new Portfolio with filtered holdings
    return Portfolio(holdings: filteredHoldings);
  }

  Portfolio filterStagnated(Map<String, List<double>> bounds, double minTpSlPadding) {
    List<Holding> filteredHoldings = holdings.where((holding) {
        List<double>? instrumentBounds = bounds[holding.instrument];

        if (instrumentBounds == null || instrumentBounds.length != 2) {
          return false;
        }

        double lowerBound = instrumentBounds[0];
        double upperBound = instrumentBounds[1];

        // Apply the padding as a percentage of the boundaries
        double paddedLowerBound = lowerBound * (1 + minTpSlPadding);
        double paddedUpperBound = upperBound * (1 - minTpSlPadding);

        return holding.takeProfit > paddedLowerBound &&
        holding.takeProfit < paddedUpperBound &&
        holding.stopLoss > paddedLowerBound &&
        holding.stopLoss < paddedUpperBound &&
        holding.stopLoss != 0 &&
        holding.takeProfit != 0;
    }).toList();

    // Return a new Portfolio with filtered holdings
    return Portfolio(holdings: filteredHoldings);
  }

  Portfolio filterTrending(Map<String, List<double>> bounds) {
    List<Holding> filteredHoldings = holdings.where((holding) {
        List<double>? instrumentBounds = bounds[holding.instrument];
        if (instrumentBounds == null || instrumentBounds.length != 2) {
          return false;
        }

        double lowerBound = instrumentBounds[0];
        double upperBound = instrumentBounds[1];

        bool isTakeProfitTrending = (holding.takeProfit > lowerBound && holding.takeProfit > upperBound) ||
        (holding.takeProfit < lowerBound && holding.takeProfit < upperBound);

        return isTakeProfitTrending;
    }).toList();

    return Portfolio(holdings: filteredHoldings);
  }

  Portfolio filterMinTpSl(Map<String, List<double>> bounds, double percentage) {
    List<Holding> filteredHoldings = holdings.where((holding) {
        List<double>? instrumentBounds = bounds[holding.instrument];
        if (instrumentBounds == null || instrumentBounds.length != 2) {
          return false;
        }

        double lowerBound = instrumentBounds[0];
        double upperBound = instrumentBounds[1];

        double maxAbsBound = max(lowerBound.abs(), upperBound.abs());

        double minThreshold = maxAbsBound * percentage;

        return holding.takeProfit.abs() > minThreshold && holding.stopLoss.abs() > minThreshold;
    }).toList();

    return Portfolio(holdings: filteredHoldings);
  }

  void filterTop(int n) {
    holdings.removeWhere((holding) {
        if (holding.takeProfit > 0) {
          return !(holding.direction1 > 0 && holding.direction2 < 0);
        } else if (holding.takeProfit < 0) {
          return !(holding.direction1 < 0 && holding.direction2 > 0);
        }
        return true;
    });

    // Then, apply your existing score-based trimming
    while (holdings.length > n) {
      // Remove lowest testingScore
      Holding? lowestTestingScore = holdings.reduce(
        (a, b) => a.testingScore < b.testingScore ? a : b,
      );
      holdings.remove(lowestTestingScore);

      if (holdings.length <= n) break;

      // Remove lowest outputScore
      Holding? lowestOutputScore = holdings.reduce(
        (a, b) => a.outputScore < b.outputScore ? a : b,
      );
      holdings.remove(lowestOutputScore);
    }
  }

  void filterBest() {
    holdings.removeWhere((holding) {
        if (holding.tpBig <= 0.0) {
          return true;
        }
        if (holding.tpWithin <= 0.0) {
          return true;
        }
        bool directionOk;
        if (holding.takeProfit > 0) {
          directionOk = holding.direction1 > 0.10 && holding.direction2 < -0.10;
        } else if (holding.takeProfit < 0) {
          directionOk = holding.direction1 < -0.10 && holding.direction2 > 0.10;
        } else {
          directionOk = false;
        }

        bool scoreOk = holding.outputScore >= 0.60;

        return !(directionOk && scoreOk);
    });
  }

  Portfolio filterOutSymbols(List<String> symbolsToExclude) {
    List<Holding> filteredHoldings = holdings.where(
      (holding) => !symbolsToExclude.contains(holding.instrument)
    ).toList();

    return Portfolio(holdings: filteredHoldings);
  }

  static List<Holding> sortHoldings(List<Holding> holdings, Map<String, double> rho) {
    List<({Holding holding, double mean})> holdingMeans = holdings.map((holding) {
        double rhoValue = rho[holding.instrument] ?? 0.0;
        // double mean = (rhoValue + holding.outputScore + holding.outputDelta) / 3.0;
        double mean = (holding.outputScore + holding.outputDelta) / 2.0;
        return (holding: holding, mean: mean);
    }).toList();

    holdingMeans.sort((a, b) => b.mean.compareTo(a.mean));

    return holdingMeans.map((e) => e.holding).toList();
  }

  @override
  String toString() {
    if (holdings.isEmpty) {
      return "Empty Portfolio";
    }

    // Determine the width of each column
    int instrumentWidth = max(
      holdings.map((h) => h.instrument.length).reduce(max),
      'Instrument'.length
    );
    int allocationWidth = max(
      holdings.map((h) => h.allocation.toStringAsFixed(2).length).reduce(max),
      'Allocation'.length
    );
    int profitWidth = max(
      holdings.map((h) => h.takeProfit.toStringAsFixed(8).length).reduce(max),
      'Take Profit'.length
    );
    int lossWidth = max(
      holdings.map((h) => h.stopLoss.toStringAsFixed(8).length).reduce(max),
      'Stop Loss'.length
    );
    int outputScoreWidth = max(
      holdings.map((h) => h.outputScore.toStringAsFixed(2).length).reduce(max),
      'Output Score'.length
    );
    int outputDeltaWidth = max(
      holdings.map((h) => h.outputDelta.toStringAsFixed(2).length).reduce(max),
      'Output Delta'.length
    );
    int testingScoreWidth = max(
      holdings.map((h) => h.testingScore.toStringAsFixed(2).length).reduce(max),
      'Testing Score'.length
    );

    // Create the header
    String header = '|${' Instrument '.padRight(instrumentWidth + 1)}|' +
    '${' Allocation '.padRight(allocationWidth + 1)}|' +
    '${' Take Profit '.padRight(profitWidth + 1)}|' +
    '${' Stop Loss '.padRight(lossWidth + 1)}|' +
    '${' Output Score '.padRight(outputScoreWidth + 1)}|' +
    '${' Dir1 '.padRight(outputDeltaWidth + 1)}|' +
    '${' Dir2 '.padRight(testingScoreWidth + 1)}|';

    // Create the separator line
    String separator = '+${'-' * (instrumentWidth + 2)}+' +
    '${'-' * (allocationWidth + 2)}+' +
    '${'-' * (profitWidth + 2)}+' +
    '${'-' * (lossWidth + 2)}+' +
    '${'-' * (outputScoreWidth + 2)}+' +
    '${'-' * (outputDeltaWidth + 2)}+' +
    '${'-' * (testingScoreWidth + 2)}+';

    // Create the rows
    List<String> rows = holdings.map((holding) =>
      '| ${holding.instrument.padRight(instrumentWidth)} |' +
      ' ${holding.allocation.toStringAsFixed(2).padLeft(allocationWidth)} |' +
      ' ${holding.takeProfit.toStringAsFixed(8).padLeft(profitWidth)} |' +
      ' ${holding.stopLoss.toStringAsFixed(8).padLeft(lossWidth)} |' +
      ' ${holding.outputScore.toStringAsFixed(2).padLeft(outputScoreWidth)} |' +
      ' ${holding.direction1.toStringAsFixed(2).padLeft(outputDeltaWidth)} |' +
      ' ${holding.direction2.toStringAsFixed(2).padLeft(testingScoreWidth)} |'
    ).toList();

    // Combine all parts
    return '\n' + [separator, header, separator, ...rows, separator].join('\n');
  }
}

class OvermindApi {
  // final String baseUrl = 'http://localhost:1989';
  // final String baseUrl = 'https://overmind.pagekite.me';
  final String baseUrl = 'http://172.20.23.250:1989';

  Future<Portfolio> trainPortfolio(
    String apiKey,
    int iterations,
    int maxTradeHorizon,
    double tpPercentage,
    double slPercentage,
  ) async {
    try {
      final Map<String, String> params = {
        'iterations': iterations.toString(),
        'maxTradeHorizon': maxTradeHorizon.toString(),
        'tpPercentage': tpPercentage.toString(),
        'slPercentage': slPercentage.toString(),
      };
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/train-all';
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // await player.play(UrlSource('https://dpoetry.com/test/games/package/files/constructFiles/Files/025832392-magic-idea-05.wav'));
        List<dynamic> jsonResponse = jsonDecode(response.body);
        Portfolio portfolio = Portfolio.fromJson(jsonResponse);
        return portfolio;
      } else {
        throw Exception('Failed to load portfolio data');
      }
    } catch (error) {
      print('Error fetching optimized portfolio: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<Portfolio> trainSomeModels(
    String apiKey,
    int iterations,
    int maxTradeHorizon,
    double tpPercentage,
    double slPercentage,
    List<String> symbols,
  ) async {
    try {
      final Map<String, String> params = {
        'iterations': iterations.toString(),
        'maxTradeHorizon': maxTradeHorizon.toString(),
        'tpPercentage': tpPercentage.toString(),
        'slPercentage': slPercentage.toString(),
        'instruments': symbols.join(","),
      };
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/train-some';
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        Portfolio portfolio = Portfolio.fromJson(jsonResponse);
        return portfolio;
      } else {
        throw Exception('Failed to load portfolio data');
      }
    } catch (error) {
      print('Error fetching optimized portfolio: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<Portfolio> resetModel(
    String apiKey,
    String symbol,
  ) async {
    try {
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/refresh-model';
      final Uri url = Uri.parse('$baseUrl$endpoint');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final Map<String, String> queryParams = {
        'instrument': symbol, // Pass the symbol as a query parameter
      };

      final Uri urlWithQuery = url.replace(queryParameters: queryParams);

      final http.Response response = await http.get(urlWithQuery, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        Portfolio portfolio = Portfolio.fromJson(jsonResponse);
        return portfolio;
      } else {
        throw Exception('Failed to refresh model for $symbol');
      }
    } catch (error) {
      print('Error refreshing model for $symbol: $error');
      return Portfolio(holdings: []); // Return an empty portfolio on failure
    }
  }

  Future<Portfolio> resetModels(
    String apiKey,
    List<String> symbols,
  ) async {
    try {
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/refresh-models';
      final Uri url = Uri.parse('$baseUrl$endpoint');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final Map<String, String> queryParams = {
        'instruments': symbols.join(","),
      };

      final Uri urlWithQuery = url.replace(queryParameters: queryParams);

      final http.Response response = await http.get(urlWithQuery, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        Portfolio portfolio = Portfolio.fromJson(jsonResponse);
        return portfolio;
      } else {
        throw Exception('Failed to refresh model for $symbols');
      }
    } catch (error) {
      print('Error refreshing model for $symbols: $error');
      return Portfolio(holdings: []); // Return an empty portfolio on failure
    }
  }

  Future<Map<String, List<double>>> getMinMaxPrices(
    String apiKey,
    int pastPricesCount
  ) async {
    try {
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/min-max-prices';
      final Map<String, String> params = {
        'n': pastPricesCount.toString(),
      };
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        Map<String, List<double>> parsedResponse = jsonResponse.map(
          (key, value) => MapEntry(
            key,
            List<double>.from(value)
          )
        );

        return parsedResponse;
      } else {
        throw Exception('Failed to fetch min max prices');
      }
    } catch (error) {
      print('Error fetching min max prices: $error');
      return {};
    }
  }

  Future<Portfolio> resetPortfolio(
    String apiKey
  ) async {
    try {
      final String token = 'Bearer $apiKey';

      final String endpoint = '/v1/portfolio/refresh';
      final Uri url = Uri.parse('$baseUrl$endpoint');

      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        Portfolio portfolio = Portfolio.fromJson(jsonResponse);
        return portfolio;
      } else {
        throw Exception('Failed to reset portfolio data');
      }
    } catch (error) {
      print('Error resetting portfolio: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<List<String>> getSymbols(String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/info/instruments';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<String> jsonResponse = (jsonDecode(response.body) as List).map((e) => e.toString()).toList();
        return jsonResponse;
      } else {
        throw Exception('Failed to load available symbols');
      }
    } catch (error) {
      print('Error fetching available symbols: $error');
      throw error;
    }
  }

  void printListWithIndentation(List<dynamic> list, {int indent = 0}) {
    print('${' ' * indent}[');
    for (var item in list) {
      if (item is Map) {
        printMapWithIndentation(item, indent: indent + 2);
      } else if (item is List) {
        printListWithIndentation(item, indent: indent + 2);
      } else {
        print('${' ' * (indent + 2)}$item');
      }
    }
    print('${' ' * indent}]');
  }

  void printMapWithIndentation(Map<dynamic, dynamic> map, {int indent = 0}) {
    print('${' ' * indent}{');
    for (var entry in map.entries) {
      if (entry.value is Map) {
        print('${' ' * (indent + 2)}${entry.key}:');
        printMapWithIndentation(entry.value, indent: indent + 4);
      } else if (entry.value is List) {
        print('${' ' * (indent + 2)}${entry.key}:');
        printListWithIndentation(entry.value, indent: indent + 4);
      } else {
        print('${' ' * (indent + 2)}${entry.key}: ${entry.value}');
      }
    }
    print('${' ' * indent}}');
  }

  Future<bool> isTrainInQueue(String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/portfolio/train-in-queue';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return jsonResponse["inQueue"] as bool ?? false;
      } else {
        throw Exception('Failed to check if in training queue');
      }
    } catch (error) {
      print('Error checking if in training queue: $error');
      return false;
    }
  }

  Future<Map<String, double>> getRho(String apiKey, List<String> instruments) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/rho';
      final String instrumentsParam = instruments.join(',');
      final Map<String, String> queryParams = {
        'instruments': instrumentsParam,
      };
      final Uri url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
      final Map<String, String> headers = {
        'Authorization': token,
      };
      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        Map<String, double> rhoMap = {};
        jsonResponse.forEach((key, value) {
            if (value is num) {
              rhoMap[key] = value.toDouble();
            } else {
              print('Warning: Value for key "$key" is not a number.  Skipping.');
            }
        });
        return rhoMap;
      } else {
        print('API Response: ${response.body}');
        throw Exception('Failed to load rho results: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching rho results: $error');
      throw error;
    }
  }

  Future<Portfolio> getPortfolio(String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/portfolio';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        return Portfolio.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load portfolio results');
      }
    } catch (error) {
      print('Error fetching portfolio results: $error');
      throw error;
    }
  }

  Future<Portfolio> getPortfolioFilter(String apiKey, List<String> symbols) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/portfolio-filter';
      final Map<String, String> params = {
        'instruments': symbols.join(","),
      };
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        return Portfolio.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load portfolio results');
      }
    } catch (error) {
      print('Error fetching portfolio results: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<Portfolio> getPortfolioFilterBalance(String apiKey, List<String> symbols, double balance, int openPositionsCount) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/portfolio-filter-balance';
      var div = 0.95;
      var finalBalance = div * balance;
      var sharePerc = 0.30;
      final capacity = (1.0 / sharePerc).floor();
      final totalOpen = symbols.length + openPositionsCount;

      if (totalOpen < capacity) {
        div = sharePerc * symbols.length;
        finalBalance = div * (balance / (1.0 - (openPositionsCount * sharePerc)));
      }

      final Map<String, dynamic> params = {
        'instruments': symbols.join(","),
        'balance': finalBalance.toString()
      };
      final Uri url = Uri.parse('$baseUrl$endpoint${Uri(queryParameters: params)}');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        return Portfolio.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load portfolio results');
      }
    } catch (error) {
      print('Error fetching portfolio results: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<Portfolio> getFuturesPortfolio(String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/portfolio';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        return Portfolio.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load portfolio results');
      }
    } catch (error) {
      print('Error fetching portfolio results: $error');
      return Portfolio(holdings: []);
    }
  }

  Future<Map<String, dynamic>> getAmherag(String symbol, String timeframe, String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/amherag?instrument=${symbol}&timeframe=${timeframe}';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to retrieve Amherag');
      }
    } catch (error) {
      print('Error fetching Amherag: $error');
      throw error;
    }
  }

  Future<Map<String, dynamic>> getLatestPrice(String apiKey, String symbol) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/latest-price?instrument=${symbol}';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to retrieve latest price');
      }
    } catch (error) {
      print('Error fetching latest price: $error');
      return {};
    }
  }

  Future<Map<String, double>> getLatestPrices(String apiKey, List<String> symbols) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/results/latest-prices?instruments=${symbols.join(",")}';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      final Map<String, String> headers = {
        'Authorization': token,
      };

      final http.Response response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return decoded.map((key, value) {
            double? price = double.tryParse(value.toString());
            return MapEntry(key, price ?? 0.0);
        });
      } else {
        throw Exception('Failed to retrieve latest price');
      }
    } catch (error) {
      print('Error fetching latest price: $error');
      throw error;
    }
  }

  Future<String> getFreeTierApiKey() async {
    try {
      // final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/auth/init-token';
      final Uri url = Uri.parse('$baseUrl$endpoint');
      // final Map<String, String> headers = {
      //   'Authorization': token,
      // };

      final http.Response response = await http.post(url);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to retrieve free-tier API key');
      }
    } catch (error) {
      print('Error fetching free-tier API key: $error');
      return "";
    }
  }
}
