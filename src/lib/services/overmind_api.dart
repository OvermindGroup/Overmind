import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' show max;
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();

class Holding {
  final double takeProfit;
  final double stopLoss;
  final double riskReward;
  final int horizon;
  final double testingScore;
  final String instrument;
  final String horizonFormatted;
  final double allocation;
  final double trainingScore;
  final double outputScore;
  final List<dynamic> lastTrades;
  final double tpVolPerc;
  final double slVolPerc;

  Holding({
      required this.takeProfit,
      required this.stopLoss,
      required this.riskReward,
      required this.horizon,
      required this.testingScore,
      required this.instrument,
      required this.horizonFormatted,
      required this.allocation,
      required this.trainingScore,
      required this.outputScore,
      required this.lastTrades,
      required this.tpVolPerc,
      required this.slVolPerc,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      takeProfit: json['takeProfit'],
      stopLoss: json['stopLoss'],
      riskReward: json['riskReward'],
      horizon: json['horizon'].toInt(),
      testingScore: json['testingScore'].toDouble(),
      instrument: json['instrument'],
      horizonFormatted: json['horizonFormatted'],
      allocation: json['allocation'].toDouble(),
      trainingScore: json['trainingScore'].toDouble(),
      outputScore: json['outputScore'].toDouble(),
      lastTrades: json['lastTrades'].toList() as List<dynamic>,
      tpVolPerc: json['tpVolPerc'].toDouble(),
      slVolPerc: json['slVolPerc'].toDouble(),
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

  Holding getHolding(String instrument) {
    return holdings.firstWhere(
      (holding) => holding.instrument == instrument,
      // orElse: () => throw StateError('Instrument $instrument not found in portfolio'),
      orElse: () => Holding(
        takeProfit: 0.0,
        stopLoss: 0.0,
        riskReward: 0.0,
        horizon: 0,
        testingScore: 0.0,
        instrument: "",
        horizonFormatted: "",
        allocation: 0.0,
        trainingScore: 0.0,
        outputScore: 0.0,
        lastTrades: [],
        tpVolPerc: 0.0,
        slVolPerc: 0.0,
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

  // void filterTop(int n) {
  //   if (holdings.length <= n) {
  //     return; // No changes needed
  //   }

  //   // Use a Priority Queue (Min Heap) to keep track of the smallest n holdings for each score criteria
  //   final testingHeap = PriorityQueue<Holding>((a, b) => a.testingScore.compareTo(b.testingScore));
  //   final trainingHeap = PriorityQueue<Holding>((a, b) => a.trainingScore.compareTo(b.trainingScore));
  //   final outputHeap = PriorityQueue<Holding>((a, b) => a.outputScore.compareTo(b.outputScore));

  //   // Add all holdings to the heaps
  //   for (final holding in holdings) {
  //     testingHeap.add(holding);
  //     trainingHeap.add(holding);
  //     outputHeap.add(holding);
  //   }

  //   // Create a Set to hold all the holdings to remove
  //   final holdingsToRemove = <Holding>{};

  //   print('filterTop start');
  //   // Remove the lowest scores until we reach n number of holdings
  //   while (holdings.length > n) {
  //     if(testingHeap.isNotEmpty) {
  //       holdingsToRemove.add(testingHeap.removeFirst());
  //     }

  //     if (holdings.length <= n) break;
  //      // clear the heap before populating from the next heap
  //     testingHeap.clear();

  //     if(trainingHeap.isNotEmpty) {
  //       holdingsToRemove.add(trainingHeap.removeFirst());
  //     }

  //     if (holdings.length <= n) break;
  //      // clear the heap before populating from the next heap
  //     trainingHeap.clear();

  //     if(outputHeap.isNotEmpty) {
  //       holdingsToRemove.add(outputHeap.removeFirst());
  //     }
  //   }

  //   // Update holdings in place
  //   holdings.removeWhere((holding) => holdingsToRemove.contains(holding));

  // }

  void filterTop(int n) {
    while (holdings.length > n) {
      // Find the holding with the lowest testingScore and remove it
      Holding? lowestTestingScore = holdings.reduce((a, b) =>
        a.testingScore < b.testingScore ? a : b);
      holdings.remove(lowestTestingScore);

      // Check if we still have more than n holdings
      if (holdings.length <= n) break;

      // Find the holding with the lowest trainingScore and remove it
      Holding? lowestTrainingScore = holdings.reduce((a, b) =>
        a.trainingScore < b.trainingScore ? a : b);
      holdings.remove(lowestTrainingScore);

      // Check if we still have more than n holdings
      if (holdings.length <= n) break;

      // Find the holding with the lowest outputScore and remove it
      Holding? lowestOutputScore = holdings.reduce((a, b) =>
        a.outputScore < b.outputScore ? a : b);
      holdings.remove(lowestOutputScore);

      // Uncomment this section to include the risk reward ratio
      // Check if we still have more than n holdings
      // if (holdings.length <= n) break;

      // Find the holding with the lowest risk/reward ratio and remove it
      // Holding? lowestRiskReward = holdings.reduce((a, b) {
      //   double riskRewardA = (a.takeProfit / a.stopLoss).isNaN ? 0.0 : (a.takeProfit / a.stopLoss).abs();
      //   double riskRewardB = (b.takeProfit / b.stopLoss).isNaN ? 0.0 : (b.takeProfit / b.stopLoss).abs();

      //   return riskRewardA < riskRewardB ? a : b;
      // });
      // holdings.remove(lowestRiskReward);
    }
  }

  // Portfolio filterTop(int n) {
  //   // Create a copy of holdings to avoid modifying the original list
  //   List<Holding> filteredHoldings = List.from(holdings);

  //   while (filteredHoldings.length > n) {
  //     // Find the holding with the lowest testingScore and remove it
  //     Holding? lowestTestingScore = filteredHoldings.reduce((a, b) =>
  //       a.testingScore < b.testingScore ? a : b);
  //     filteredHoldings.remove(lowestTestingScore);

  //     // Check if we still have more than n holdings
  //     if (filteredHoldings.length <= n) break;

  //     // Find the holding with the lowest trainingScore and remove it
  //     Holding? lowestTrainingScore = filteredHoldings.reduce((a, b) =>
  //       a.trainingScore < b.trainingScore ? a : b);
  //     filteredHoldings.remove(lowestTrainingScore);

  //     // Check if we still have more than n holdings
  //     if (filteredHoldings.length <= n) break;

  //     // Find the holding with the lowest outputScore and remove it
  //     Holding? lowestOutputScore = filteredHoldings.reduce((a, b) =>
  //       a.outputScore < b.outputScore ? a : b);
  //     filteredHoldings.remove(lowestOutputScore);

  //     // // Check if we still have more than n holdings
  //     // if (filteredHoldings.length <= n) break;

  //     // // Find the holding with the lowest risk/reward ratio and remove it
  //     // Holding? lowestRiskReward = filteredHoldings.reduce((a, b) {
  //     //     double riskRewardA = (a.takeProfit / a.stopLoss).isNaN ? 0.0 : (a.takeProfit / a.stopLoss).abs();
  //     //     double riskRewardB = (b.takeProfit / b.stopLoss).isNaN ? 0.0 : (b.takeProfit / b.stopLoss).abs();

  //     //     return riskRewardA < riskRewardB ? a : b;
  //     // });
  //     // filteredHoldings.remove(lowestRiskReward);
  //   }

  //   return Portfolio(holdings: filteredHoldings);
  // }

  Portfolio filterOutSymbols(List<String> symbolsToExclude) {
    List<Holding> filteredHoldings = holdings.where(
      (holding) => !symbolsToExclude.contains(holding.instrument)
    ).toList();

    return Portfolio(holdings: filteredHoldings);
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
    '${' Testing Score '.padRight(testingScoreWidth + 1)}|';

    // Create the separator line
    String separator = '+${'-' * (instrumentWidth + 2)}+' +
    '${'-' * (allocationWidth + 2)}+' +
    '${'-' * (profitWidth + 2)}+' +
    '${'-' * (lossWidth + 2)}+' +
    '${'-' * (outputScoreWidth + 2)}+' +
    '${'-' * (testingScoreWidth + 2)}+';

    // Create the rows
    List<String> rows = holdings.map((holding) =>
      '| ${holding.instrument.padRight(instrumentWidth)} |' +
      ' ${holding.allocation.toStringAsFixed(2).padLeft(allocationWidth)} |' +
      ' ${holding.takeProfit.toStringAsFixed(8).padLeft(profitWidth)} |' +
      ' ${holding.stopLoss.toStringAsFixed(8).padLeft(lossWidth)} |' +
      ' ${holding.outputScore.toStringAsFixed(2).padLeft(outputScoreWidth)} |' +
      ' ${holding.testingScore.toStringAsFixed(2).padLeft(testingScoreWidth)} |'
    ).toList();

    // Combine all parts
    return '\n' + [separator, header, separator, ...rows, separator].join('\n');
  }
}

class OvermindApi {
  // final String baseUrl = 'http://localhost:1989';
  final String baseUrl = 'https://overmind.pagekite.me';
  // final String baseUrl = 'http://172.20.23.250:1989';

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
      return [];
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
      return Portfolio(holdings: []);
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

  Future<Map<String, dynamic>> getAmherag(String symbol, String apiKey) async {
    try {
      final String token = 'Bearer $apiKey';
      final String endpoint = '/v1/amherag?instrument=${symbol}';
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
      return {};
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
      return {};
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
