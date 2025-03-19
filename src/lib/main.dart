// import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
// import 'package:candlesticks/candlesticks.dart';
// import 'package:http/http.dart' as http;
import 'package:fullscreen_window/fullscreen_window.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart'
if (dart.library.html) 'package:window_manager/window_manager_stub.dart';
// import 'package:graphic/graphic.dart';
// import 'package:pluto_menu_bar/pluto_menu_bar.dart';
import 'widgets/top_menu_bar.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'database/database.dart';
// import 'package:drift/drift.dart' hide Column;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sizer/flutter_sizer.dart';
import 'dart:async';
import 'widgets/basic.dart';
import 'widgets/optimization_settings.dart';
// import 'widgets/positions.dart';
import 'widgets/portfolio.dart';
import 'services/binance_api.dart';
import 'services/overmind_api.dart';
import 'package:fluttertoast/fluttertoast.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
FToast fToast = FToast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape mode on mobile
  await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
  ]);

  runApp(Overmind());

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    windowManager.waitUntilReadyToShow().then((_) async {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    });
  }
}

class Overmind extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    FullScreenWindow.setFullScreen(true);
    return FlutterSizer(
      builder: (context, orientation, screenType) {
        return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1),
      ),
      child: MaterialApp(
          builder: FToastBuilder(),
          title: 'Overmind',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: HomeScreen(),
          navigatorKey: navigatorKey,
        ),
    );
    });
  }
}

class MyDropdown extends StatefulWidget {
  @override
  _MyDropdownState createState() => _MyDropdownState();
}

class _MyDropdownState extends State<MyDropdown> {
  String? _selectedItem;
  final List<String> _items = ['One', 'Two', 'Three', 'Four'];

  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: EdgeInsets.all(16.0),
      child: DropdownButtonFormField<String>(
        value: _selectedItem,
        hint: Text('Select an item'),
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Dropdown',
        ),
        items: _items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
              _selectedItem = newValue;
          });
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _iterations = 50;
  int _maxTradeHorizon = 288;
  double _takeProfit = 100.0;
  double _stopLoss = 100.0;
  late double _amheragHeight;
  String _symbol = "BTCUSDT";
  double _tp = 0.0;
  double _sl = 0.0;
  double _newTp = 0.0;
  double _newSl = 0.0;
  double _entryPrice = 0.0;
  int _filterTopN = 10;

  double _minTpVolPerc = 0.02;
  // double _maxTpVolPerc = 0.0;
  double _minSlVolPerc = 0.02;
  // double _maxSlVolPerc = 0.0;
  double _tradePercAllocation = 0.20;
  double _allocationUSDT = 20.0;
  int _leverage = 1;
  Map<String, double> _latestPrices = {};
  bool _isAutoTrade = false;
  
  late List<CandleData> candles = [];

  BinanceApi binance = BinanceApi();
  OvermindApi overmind = OvermindApi();

  late Map<String, dynamic> _openPositions = {};
  Map<String, List<double>> userAsset = {};
  late Portfolio fullOptimizedPortfolio;
  late Portfolio optimizedPortfolio;
  late Investment? latestInvestment;
  List<String> symbols = [];
  late OvermindDb db;

  late Future<bool> _isSecureStorageAvailable;
  late SharedPreferences _prefs;

  final _secureStorage = FlutterSecureStorage();
  String _binanceApiKey = '';
  String _binanceApiSecret = '';
  String _overmindApiKey = '';
  String _quoteSymbol = 'USDT';

  TextEditingController _binanceApiKeyController = TextEditingController();
  TextEditingController _binanceApiSecretController = TextEditingController();
  TextEditingController _overmindApiKeyController = TextEditingController();

  Set<String> _excludedSymbols = {};

  late StreamSubscription _positionsStream;

  OptimizationSettings _optimizationSettings = OptimizationSettings();

  late ValueNotifier<Map<String, dynamic>> _openPositionsNotifier;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    db = OvermindDb();
    _isSecureStorageAvailable = _checkSecureStorage();
    _openPositionsNotifier = ValueNotifier({});
    _loadApiKeys().then((_) {
        if (!_isBinanceApiKeysSet() || !_isOvermindApiKeySet()) {
          _showApiKeysModal(navigatorKey.currentContext!);
          return;
        }
        _initChart();
    });
    _startPositionsStream();
    // startAutomatedTrading();

    super.initState();

    // fToast = FToast();
    // if you want to use context from globally instead of content we need to pass navigatorKey.currentContext!
    fToast.init(navigatorKey.currentContext!);
  }

  void _initChart() {
    _fetchOpenPositions().then((_) {
        return _updatePortfolio().then((_) {
            return fetchSymbols().then((_symbols) {
                populateChart();
                setState(() {
                    symbols = _symbols;
                });
                _setNewTpSl(_symbol);
            });
        });
    });
  }

  @override
  void dispose() {
    _positionsStream.cancel();
    _openPositionsNotifier.dispose();
    super.dispose();
  }

  bool _isBinanceApiKeysSet() {
    return _binanceApiKey != '' && _binanceApiSecret != '';
  }

  bool _isOvermindApiKeySet() {
    return _overmindApiKey != '';
  }

  void _startPositionsStream() {
    _positionsStream = Stream.periodic(const Duration(seconds: 10)).listen((_) {
        _fetchOpenPositions();
    });
  }

  Future<void> fetchPositions() async {
    await _fetchOpenPositions();
  }

  Future<List<String>> _fetchLastHourLostSymbols() async {
    // Get the current time (endDate)
    DateTime endDate = DateTime.now();

    // Subtract one hour to get the startDate
    DateTime startDate = endDate.subtract(Duration(hours: 1));

    // Fetch the user trades for the last hour
    final userTrades = await binance.getUserTrades(_binanceApiKey, _binanceApiSecret, startDate, endDate);
    return userTrades.where((trade) => double.parse(trade["realizedPnl"].toString()) < 0).toList().map((trade) => trade["symbol"] as String).toList();
  }

  // Future<void> fetchAndExecutePortfolio() async {
  //   // Train portfolio
  //   // await overmind.trainPortfolio(_overmindApiKey, 1, _maxTradeHorizon, _takeProfit / 1.0, _stopLoss / 1.0);
  //   // Fetch the portfolio
  //   await _updatePortfolio().then((_) async {
  //       final symbols = optimizedPortfolio.symbols;
  //       // Check if symbols has at least one item before executing
  //       if (symbols.length > 0) {
  //         await _executePortfolio();
  //       }
  //   });
  // }

  // void startAutomatedTrading() {
  //   Timer.periodic(Duration(seconds: 90), (Timer timer) async {
  //       if (_isAutoTrade) {
  //         await fetchAndExecutePortfolio();
  //       }
  //   });
  // }

  Future<Portfolio> _fetchPortfolio() async {
    // final fullPortfolio = await overmind.getPortfolio(_overmindApiKey);
    // var filteredPortfolio = Portfolio(holdings: fullPortfolio.holdings);

    return overmind.getPortfolio(_overmindApiKey);
  }

  Future<Portfolio> _filterPortfolio(Portfolio portfolio) async {
    // final symbols = fullPortfolio.map((holding) => holding.instrument);

    if (_optimizationSettings.filterTopN > 0) {
      // filteredPortfolio = fullPortfolio.filterTop(_optimizationSettings.filterTopN);
      portfolio.filterTop(_optimizationSettings.filterTopN);
    }//  else {
    //   filteredPortfolio = fullPortfolio;
    // }

    // if (_optimizationSettings.selectedMinTpSl > 0.0 && _optimizationSettings.selectedMarketType != "noPreference") {
    //   final minMax = await overmind.getMinMaxPrices(_overmindApiKey, _optimizationSettings.sandrPastN);
    //   if (_optimizationSettings.selectedMarketType == "stagnatedMarkets") {
    //     filteredPortfolio = filteredPortfolio.filterStagnated(minMax, _optimizationSettings.minTpSlPadding);
    //   } else {
    //     filteredPortfolio = filteredPortfolio.filterTrending(minMax);
    //   }

    //   if (_optimizationSettings.selectedMinTpSl > 0.0) {
    //     filteredPortfolio = filteredPortfolio.filterMinTpSl(minMax, _optimizationSettings.selectedMinTpSl);
    //   }
    // }

    // if (_optimizationSettings.filterOutLostSymbols) {
    //   final lostSymbols = await _fetchLastHourLostSymbols();
    //   // print('Filtering out lost symbols: $lostSymbols');
    //   filteredPortfolio = filteredPortfolio.filterOutSymbols(lostSymbols);
    // }

    // if (_optimizationSettings.filterOutHeldAssets) {
    //   final positions = _openPositions["portfolio"];
    //   final symbols = positions.map((position) => position["symbol"]).cast<String>().toList();
    //   filteredPortfolio = filteredPortfolio.filterOutSymbols(symbols);
    // }

    // filteredPortfolio = filteredPortfolio.filterByScores(_optimizationSettings.minRiskReward, _optimizationSettings.maxRiskReward, _optimizationSettings.minTestingScore, _optimizationSettings.minOutputScore, _minTpVolPerc, _minSlVolPerc);

    // Removing any excluded symbols
    // filteredPortfolio = filteredPortfolio.filterOutSymbols(_excludedSymbols.toList());

    // if (_optimizationSettings.showAffordable) {
    //   filteredPortfolio = await _filterPortfolioByBalance(filteredPortfolio);
    // }

    return portfolio;
  }

  Future<Portfolio> _updatePortfolio() async {
    final fullPortfolio = await overmind.getPortfolio(_overmindApiKey);
    var filteredPortfolio = Portfolio(holdings: fullPortfolio.holdings);
    await _filterPortfolio(filteredPortfolio);
    final latestPrices = await overmind.getLatestPrices(_overmindApiKey, filteredPortfolio.symbols);
    setState(() {
        _latestPrices = latestPrices;
        fullOptimizedPortfolio = fullPortfolio;
        optimizedPortfolio = filteredPortfolio;
    });
    return filteredPortfolio;
  }

  Future<void> _processPositions(List<dynamic> positions) async {
    try{
      final List<String> symbols = positions.map((position) => position["symbol"] as String).toList();
      final prices = await binance.getPrices(symbols);
      final List<List<dynamic>> orders = await Future.wait(
        symbols.map((symbol) => binance.getUserOpenOrders(_binanceApiKey, _binanceApiSecret, symbol))
      );

      final balance = await binance.getUserBalance(_binanceApiKey, _binanceApiSecret, _quoteSymbol);
      final double totalBalance = double.parse(balance["balance"] ?? '0');
      final double availableBalance = double.parse(balance["availableBalance"] ?? '0');
      final double unrealizedProfit = double.parse(balance["crossUnPnl"] ?? '0');
      final List<Map<String, dynamic>> portfolio = [];

      for (int i = 0; i < positions.length; i++) {
        final position = positions[i];
        final symbol = position["symbol"];
        final entryPrice = double.parse(position["entryPrice"]);
        final unRealizedProfit = double.parse(position["unRealizedProfit"] ?? '0');
        final amount = double.parse(position["positionAmt"] ?? '0');
        final initialMargin = double.parse(position["initialMargin"] ?? '0');

        double tpDistance = 0.0;
        double slDistance = 0.0;
        double tpPrice = 0.0;
        double slPrice = 0.0;
        final orderList = orders[i];

        if (orderList.length > 0) {
          final stopPrice1 = orderList.isNotEmpty ? double.parse(orderList[0]["stopPrice"] ?? '0') : 0.0;
          final stopPrice2 = orderList.length > 1 ? double.parse(orderList[1]["stopPrice"] ?? '0') : 0.0;
          tpPrice = stopPrice1;
          slPrice = stopPrice2;
          if (orderList[0]["type"] == "STOP_MARKET") {
            tpPrice = stopPrice2;
            slPrice = stopPrice1;
          }

          final currentPrice = prices[symbol] ?? 0.0;

          tpDistance = amount > 0 ? (tpPrice - currentPrice) / currentPrice * 100 : (currentPrice - tpPrice) / currentPrice * 100;
          slDistance = amount > 0 ? (currentPrice - slPrice) / currentPrice * 100 : (slPrice - currentPrice) / currentPrice * 100;
        }

        portfolio.add({
            "symbol": symbol,
            "entryPrice": entryPrice,
            "tpPrice": tpPrice,
            "slPrice": slPrice,
            "tpDistance": tpDistance > 0.0 ? tpDistance / (tpDistance + slDistance) * 100.0 : 0.0,
            "slDistance": slDistance > 0.0 ? slDistance / (tpDistance + slDistance) * 100.0 : 0.0,
            "unRealizedProfit": unRealizedProfit,
            "initialMargin": initialMargin,
        });
      }

      final newOpenPositions = {
        "totalBalance": totalBalance,
        "availableBalance": availableBalance,
        "unRealizedProfit": unrealizedProfit,
        "positionsCount": positions.length,
        "portfolio": portfolio,
      };

      _openPositionsNotifier.value = newOpenPositions;
      _openPositions = newOpenPositions;
    } catch (e){
      print('Error Processing Positions $e');
      // Handle the error accordingly
    }
  }

  Future<void> _fetchOpenPositions() async {
    // binance.getUserOpenPositionsWS(_binanceApiKey, _binanceApiSecret).listen((positions) {
    //     _processPositions(positions);
    // });
    if (!_isBinanceApiKeysSet()) {
      return;
    }
    final positions = await binance.getUserOpenPositions(_binanceApiKey, _binanceApiSecret);
    _processPositions(positions);
  }

  Future<Portfolio> _filterPortfolioByBalance(Portfolio filteredPortfolio) async {
    final balance = await binance.getUserBalance(_binanceApiKey, _binanceApiSecret, _quoteSymbol);
    final filteredSymbols = filteredPortfolio.map((holding) => holding.instrument);
    final minQuantities = await binance.futuresMinimumQuantities(filteredSymbols);
    final positions = await binance.getUserOpenPositions(_binanceApiKey, _binanceApiSecret);
    final portfolioNewAllocations = await overmind.getPortfolioFilterBalance(_overmindApiKey, filteredSymbols, double.parse(balance['availableBalance']) ?? 0.0, positions.length);

    final validHoldings = portfolioNewAllocations.where((holding) {
        final minQty = double.parse(minQuantities[holding.instrument]?['minQuantity']);
        if (minQty == null) return false;
        return holding.allocation > (minQty ?? 0.0);
    });

    final validSymbols = validHoldings.map((holding) => holding.instrument);
    return await overmind.getPortfolioFilterBalance(_overmindApiKey, validSymbols, double.parse(balance['availableBalance']) ?? 0.0, positions.length);
  }

  Future<void> _tradeHolding(Holding holding) async {
    String symbol = holding.instrument;
    final latestPrice = await overmind.getLatestPrice(_overmindApiKey, symbol);
    final price = latestPrice["close"];
    final minQty = await binance.futuresMinimumQuantities([symbol]);
    final pricePrecision = minQty[symbol]!["pricePrecision"];
    final quantityPrecision = minQty[symbol]!["quantityPrecision"];

    final takeProfit = (price ?? 0.0) + (holding.takeProfit ?? 0.0);
    final stopLoss = (price ?? 0.0) + (holding.stopLoss ?? 0.0);
    final formattedTp = takeProfit.toStringAsFixed(pricePrecision);
    final formattedSl = stopLoss.toStringAsFixed(pricePrecision);
    final balance = await binance.getUserBalance(_binanceApiKey, _binanceApiSecret, _quoteSymbol);
    final totalBalance = double.parse(balance["balance"] ?? '0');
    final availableBalance = double.parse(balance["availableBalance"] ?? '0');
    // final allocationUSDT = ((totalBalance * 0.95) * _tradePercAllocation);
    final allocationUSDT = _allocationUSDT;
    final allocation = allocationUSDT / price;
    // final allocation = holding.allocation / price;
    final formattedQty = allocation.toStringAsFixed(quantityPrecision);

    if (availableBalance < allocationUSDT) {
      print('Not enough balance ($availableBalance < $allocationUSDT) for opening a new position for $symbol');
      return;
    }

    final side = holding.takeProfit > 0.0 ? "BUY" : "SELL";
    final sideStop = holding.takeProfit > 0.0 ? "SELL" : "BUY";

    await binance.changeLeverage(_binanceApiKey, _binanceApiSecret, symbol, _leverage);
    await binance.cancelAllOrders(_binanceApiKey, _binanceApiSecret, symbol).then((resp) async {
        if (resp["code"] != 200) {
          // Something wrong happened, go with next symbol.
          print('Something went wrong when trying to close old orders');
          return;
        }

        try {
          // Create Take Profit Order
          final takeProfitResponse = await binance.createTakeProfitOrder(
            _binanceApiKey,
            _binanceApiSecret,
            symbol,
            sideStop,
            formattedQty,
            formattedTp,
          );

          if (takeProfitResponse['status'] != 'NEW') {
            throw Exception('Take Profit order creation failed: ${takeProfitResponse}');
          }

          // Create Stop Loss Order
          final stopLossResponse = await binance.createStopLossOrder(
            _binanceApiKey,
            _binanceApiSecret,
            symbol,
            sideStop,
            formattedQty,
            formattedSl,
          );

          if (stopLossResponse['status'] != 'NEW') {
            throw Exception('Stop Loss order creation failed: ${stopLossResponse}');
          }

          // Create Futures Market Order
          final marketOrderResponse = await binance.createFuturesMarketOrder(
            _binanceApiKey,
            _binanceApiSecret,
            symbol,
            side,
            formattedQty,
          );

          if (marketOrderResponse['status'] == 'NEW' || marketOrderResponse['status'] == 'FILLED') {
            await _fetchOpenPositions();
            final msg = '$symbol: Market order created successfully';
            print(msg);
            _showToast(msg);
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(msg),
            //     backgroundColor: Colors.white,
            //     duration: Duration(seconds: 5),
            //   ),
            // );
          } else {
            final msg = '$symbol: Market order creation failed: ${marketOrderResponse["msg"]}';
            _showToast(msg);
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(msg),
            //     backgroundColor: Colors.white,
            //     duration: Duration(seconds: 5),
            //   ),
            // );
            throw Exception(msg);
          }
        } catch (e) {
          print('Error: $e');
        }
    });
  }

  // Future<void> _executePortfolio() async {
  //   final holdings = optimizedPortfolio.holdings;
  //   final symbols = optimizedPortfolio.symbols;
  //   for (String symbol in symbols) {
  //     final positions = await binance.getUserOpenPositionsBySymbol(_binanceApiKey, _binanceApiSecret, symbol);
  //     if (positions.length > 0) {
  //       // This shouldn't happen. If it happens, the portfolio didn't get updated correctly.
  //       print('Something went wrong in _executePortfolio');
  //       return;
  //     }
  //   }
  //   for (Holding holding in holdings) {
  //     await _tradeHolding(holding);
  //   }
  // }

  Future<bool> _checkSecureStorage() async {
    try {
      final storage = FlutterSecureStorage();
      await storage.write(key: 'test', value: 'test');
      await storage.delete(key: 'test');
      return true;
    } catch (e) {
      print('Secure storage not available: $e');
      return false;
    }
  }

  void _setNewTpSl(String symbol) {
    final currentSymbol = symbol.substring(0, symbol.length - 4);
    if (fullOptimizedPortfolio.getHolding(symbol).takeProfit != 0.0) {
      final asset = fullOptimizedPortfolio.getHolding(symbol);
      setState(() {
          _newTp = asset.takeProfit;
          _newSl = asset.stopLoss;
      });
    }
    if (_openPositions != null) {
      for (var asset in _openPositions["portfolio"]) {
        if (symbol == asset["symbol"]) {
          setState(() {
              _tp = asset["tpPrice"];
              _sl = asset["slPrice"];
              _entryPrice = asset["entryPrice"];
          });
          break;
        }
      }
    }
  }

  void _handleSymbolSelected(String symbol) {
    setState(() {
        _symbol = symbol;
        _tp = 0.0;
        _sl = 0.0;
        _newTp = 0.0;
        _newSl = 0.0;
        _entryPrice = 0.0;
    });
    _setNewTpSl(symbol);
    populateChart();
  }

  void _handleAutoTrade(BuildContext context) {
    _isAutoTrade = !_isAutoTrade;
    String msg = '';
    msg = 'Stopping automatic trading';
    if (_isAutoTrade) {
      msg = 'Starting automatic trading';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<List<String>> fetchSymbols() async {
    return await overmind.getSymbols(_overmindApiKey);
  }

  void populateChart() {
    setState(() {
        candles = [];
    });
    fetchCandles().then((value) {
        List<CandleData> _candles = [];
        for (int i = 0; i < value.length; i++) {
          final row = value[i];
          // DateTime dateTime = DateTime.parse(row['timestamp']);
          // int unixTimestamp = dateTime.millisecondsSinceEpoch ~/ 1000;
          int unixTimestamp = row['timestamp'];

          final List<double>? above = (row['amheragAbove'] as List<dynamic>?)?.map((e) => e as double).toList();
          final List<double>? below = (row['amheragBelow'] as List<dynamic>?)?.map((e) => e as double).toList();

          _candles.add(CandleData(
              timestamp: unixTimestamp,
              open: row['open']?.toDouble(),
              high: row['high']?.toDouble(),
              low: row['low']?.toDouble(),
              close: row['close']?.toDouble(),
              volume: row['volume']?.toDouble(),
              amheragAbove: above,
              amheragBelow: below,
              amheragMax: row['amheragMax'],
              amheragMin: row['amheragMin'],
          ));
        }

        setState(() {
            candles = _candles;
        });
    });
  }

  Future<List<Map<String, dynamic>>> fetchCandles() async {
    return overmind.getAmherag(_symbol, _overmindApiKey).then((_candles) {
        setState(() {
            _amheragHeight = _candles['height'];
        });
        final candles = (_candles['candles'] as List<dynamic>)
        .map((e) {
            return <String, dynamic>{
              // "time": formattedDateTime,
              "timestamp": e['candle']['date'],
              "open": e['candle']['open'],
              "high": e['candle']['high'],
              "low": e['candle']['low'],
              "close": e['candle']['close'],
              "volume": e['candle']['volume'],
              "amheragAbove": e['above'],
              "amheragBelow": e['below'],
              "amheragMax": e['max'],
              "amheragMin": e['min'],
            };
        }).toList();
        return candles as List<Map<String, dynamic>>;
    });
  }

  Future<void> _loadApiKeys() async {
    _prefs = await SharedPreferences.getInstance();
    bool useSecureStorage = await _isSecureStorageAvailable;

    if (useSecureStorage) {
      final storage = FlutterSecureStorage();
      _binanceApiKey = await storage.read(key: 'binance_api_key') ?? '';
      _binanceApiSecret = await storage.read(key: 'binance_api_secret') ?? '';
      _overmindApiKey = await storage.read(key: 'overmind_api_key') ?? '';
    } else {
      _binanceApiKey = _prefs.getString('binance_api_key') ?? '';
      _binanceApiSecret = _prefs.getString('binance_api_secret') ?? '';
      _overmindApiKey = _prefs.getString('overmind_api_key') ?? '';
    }

    setState(() {
        _binanceApiKeyController.text = _binanceApiKey;
        _binanceApiSecretController.text = _binanceApiSecret;
        _overmindApiKeyController.text = _overmindApiKey;
    });
  }

  Future<void> _saveApiKeys() async {
    bool useSecureStorage = await _isSecureStorageAvailable;

    _binanceApiKey = _binanceApiKeyController.text;
    _binanceApiSecret = _binanceApiSecretController.text;
    _overmindApiKey = _overmindApiKeyController.text;

    if (useSecureStorage) {
      final storage = FlutterSecureStorage();
      await storage.write(key: 'binance_api_key', value: _binanceApiKey);
      await storage.write(key: 'binance_api_secret', value: _binanceApiSecret);
      await storage.write(key: 'overmind_api_key', value: _overmindApiKey);
    } else {
      await _prefs.setString('binance_api_key', _binanceApiKey);
      await _prefs.setString('binance_api_secret', _binanceApiSecret);
      await _prefs.setString('overmind_api_key', _overmindApiKey);
    }

    setState(() {});
  }

  void _showApiKeysModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double widthFactor = constraints.maxWidth > 600 ? 0.8 : 1.0;
                return FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('API Keys',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          SizedBox(height: 12),
                          Text(!_isBinanceApiKeysSet() ? 'Please provide your Binance API key and secret' : '',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                          SizedBox(height: 12),
                          buildTextField('Binance API Key', _binanceApiKeyController),
                          SizedBox(height: 16),
                          buildTextField('Binance API Secret', _binanceApiSecretController),
                          SizedBox(height: 8),
                          Text(!_isOvermindApiKeySet() ? 'Please provide your Overmind PRO API key' : '',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                          SizedBox(height: 8),
                          buildTextField('Overmind API Key', _overmindApiKeyController),
                          SizedBox(height: 16),
                          _isOvermindApiKeySet() ? Row() :
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Expanded(
                              //   child: buildTextField('Overmind API Key', _overmindApiKeyController),
                              // ),
                              // SizedBox(width: 16),
                              Text('Or request a free-tier key:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                              SizedBox(width: 16),
                              ElevatedButton(
                                child: Text('Get Free-Tier Key'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.green,
                                  // padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                onPressed: () async {
                                  await _getFreeTierKey();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            child: Text('Store Securely'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            onPressed: () async {
                              await _saveApiKeys();
                              _initChart();
                              Navigator.pop(context);
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTrainingModal(BuildContext context, bool isTrainSubparModels) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double widthFactor = constraints.maxWidth > 600 ? 0.8 : 1.0;

                return FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('Training Settings',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          SizedBox(height: 24),
                          buildSlider('Iterations', _iterations, 100.0, (value) {
                              setState(() => _iterations = value.toInt());
                          }),
                          SizedBox(height: 16),
                          buildSlider('Max Trade Horizon (in hours)', _maxTradeHorizon, 288.0, (value) {
                              setState(() => _maxTradeHorizon = value.toInt());
                          }),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              buildDropdown('Take Profit (%)', _takeProfit,
                                (List.generate(10, (index) => (index + 1) * 10)).reversed.toList(),
                                (value) => setState(() => _takeProfit = value!.toDouble())),
                              buildDropdown('Stop Loss (%)', _stopLoss,
                                (List.generate(10, (index) => (index + 1) * 10)).reversed.toList(),
                                (value) => setState(() => _stopLoss = value!.toDouble())),
                            ],
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            child: Text('Start Training'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            onPressed: () {
                              if (isTrainSubparModels) {
                                final symbols = _getSubparSymbols();
                                overmind.trainSomeModels(_overmindApiKey, _iterations, _maxTradeHorizon, _takeProfit / 100.0, _stopLoss / 100.0, symbols).then((optimizedPortfolio) {
                                    this.fullOptimizedPortfolio = optimizedPortfolio;
                                    this.optimizedPortfolio = optimizedPortfolio;
                                });
                              } else {
                                overmind.trainPortfolio(_overmindApiKey, _iterations, _maxTradeHorizon, _takeProfit / 100.0, _stopLoss / 100.0).then((optimizedPortfolio) {
                                    this.fullOptimizedPortfolio = optimizedPortfolio;
                                    this.optimizedPortfolio = optimizedPortfolio;
                                });
                              }
                              // Navigator.pop(context);
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateTakeProfit(BuildContext context, String symbol) async {
    final orders = await binance.getUserOpenOrders(_binanceApiKey, _binanceApiSecret, symbol);
    final latestPrice = await overmind.getLatestPrice(_overmindApiKey, symbol);
    final price = latestPrice["close"];
    final minQty = await binance.futuresMinimumQuantities([symbol]);
    final pricePrecision = minQty[symbol]!["pricePrecision"];

    for (final order in orders) {
      final type = order["type"];
      if(type == "TAKE_PROFIT_MARKET") {
        final holding = fullOptimizedPortfolio.getHolding(symbol);
        final id = order["orderId"].toString();
        final origQty = order["origQty"];
        final side = order["side"];
        final takeProfit = (price ?? 0.0) + (holding.takeProfit ?? 0.0);
        final formattedTp = takeProfit.toStringAsFixed(pricePrecision);
        binance.cancelOrder(_binanceApiKey, _binanceApiSecret, id, symbol).then((res) {
            if (res["status"] == "CANCELED") {
              binance.createTakeProfitOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty, formattedTp).then((res) {
                  String msg = '';
                  if (res["status"] == "NEW") {
                    msg = '$symbol take profit order updated';
                  } else {
                    msg = 'Something went wrong';
                  }
                  // _fetchOpenPositions().then((_) {
                  //     populateChart();
                  // });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: Colors.white,
                      duration: Duration(seconds: 5),
                    ),
                  );
              });
            }
        });
        break;
      }
    }
    await _fetchOpenPositions();
  }

  void _updateStopLoss(BuildContext context, String symbol) async {
    final orders = await binance.getUserOpenOrders(_binanceApiKey, _binanceApiSecret, symbol);
    final latestPrice = await overmind.getLatestPrice(_overmindApiKey, symbol);
    final price = latestPrice["close"];
    final minQty = await binance.futuresMinimumQuantities([symbol]);
    final pricePrecision = minQty[symbol]!["pricePrecision"];

    for (final order in orders) {
      final type = order["type"];
      if(type == "STOP_MARKET") {
        final holding = fullOptimizedPortfolio.getHolding(symbol);
        final id = order["orderId"].toString();
        final origQty = order["origQty"];
        final side = order["side"];
        final stopLoss = (price ?? 0.0) + (holding.stopLoss ?? 0.0);
        final formattedSl = stopLoss.toStringAsFixed(pricePrecision);
        binance.cancelOrder(_binanceApiKey, _binanceApiSecret, id, symbol).then((res) {
            if (res["status"] == "CANCELED") {
              binance.createStopLossOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty, formattedSl).then((res) {
                  String msg = '';
                  if (res["status"] == "NEW") {
                    msg = '$symbol stop loss order updated';
                  } else {
                    msg = 'Something went wrong';
                  }
                  // _fetchOpenPositions().then((_) {
                  //     populateChart();
                  // });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: Colors.white,
                      duration: Duration(seconds: 5),
                    ),
                  );
              });
            }
        });
        break;
      }
    }
    await _fetchOpenPositions();
  }

  void _updateBoth(BuildContext? context, String symbol) async {
    final positions = await binance.getUserOpenPositionsBySymbol(_binanceApiKey, _binanceApiSecret, symbol);
    final position = positions[0];
    // final orders = await binance.getUserOpenOrders(_binanceApiKey, _binanceApiSecret, symbol);
    final latestPrice = await overmind.getLatestPrice(_overmindApiKey, symbol);
    final price = latestPrice["close"] ?? 0.0;
    final minQty = await binance.futuresMinimumQuantities([symbol]);
    final pricePrecision = minQty[symbol]!["pricePrecision"];

    final numQty = double.parse(position["positionAmt"] ?? '0');
    final origQty = (numQty.abs()).toString();
    final side = numQty > 0 ? "SELL" : "BUY";
    final holding = fullOptimizedPortfolio.getHolding(symbol);

    final entryPrice = double.parse(position["entryPrice"]);
    final takeProfit = price + (holding.takeProfit ?? 0.0);
    final stopLoss = price + (holding.stopLoss ?? 0.0);
    final formattedTp = takeProfit.toStringAsFixed(pricePrecision);
    final formattedSl = stopLoss.toStringAsFixed(pricePrecision);

    final isClose = (holding.takeProfit >= holding.stopLoss && side == "BUY") ||
    (holding.takeProfit <= holding.stopLoss && side == "SELL") ||
    (takeProfit >= price && stopLoss >= price) ||
    (takeProfit <= price && stopLoss <= price);

    binance.cancelAllOrders(_binanceApiKey, _binanceApiSecret, symbol).then((res) async {
        if (res["code"] == 200) {
          if (isClose) {
            await binance.createFuturesMarketOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty).then((_) {
                print('Position and orders closed for $symbol, $side, $origQty');
            });
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$symbol position and stop orders closed'),
                  backgroundColor: Colors.white,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
          binance.createTakeProfitOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty, formattedTp).then((_) {
              binance.createStopLossOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty, formattedSl).then((_) {
                  // _fetchOpenPositions().then((_) {
                  //     populateChart();
                  // });
                  print('Stop orders updated for $symbol, $side, $origQty');
                  if (context != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$symbol take profit and stop loss updated'),
                        backgroundColor: Colors.white,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
              });
          });
        }
    });
    await _fetchOpenPositions();
  }

  void _closePosition(BuildContext? context, String symbol) async {
    final positions = await binance.getUserOpenPositionsBySymbol(_binanceApiKey, _binanceApiSecret, symbol);
    final position = positions[0];
    final numQty = double.parse(position["positionAmt"] ?? '0');
    final origQty = (numQty.abs()).toString();
    final side = numQty > 0 ? "SELL" : "BUY";

    binance.cancelAllOrders(_binanceApiKey, _binanceApiSecret, symbol).then((res) async {
        if (res["code"] == 200) {
          await binance.createFuturesMarketOrder(_binanceApiKey, _binanceApiSecret, symbol, side, origQty).then((_) {
              print('Position and orders closed for $symbol, $side, $origQty');
          });
          _showToast("Position and orders closed for ${symbol}");
          return;
        } else {
          _showToast("Something went wrong when trying to close orders for ${symbol}");
        }
    });
    await _fetchOpenPositions();
  }

  List<Map<String, dynamic>> _groupAndTransformOrders(List<Map<String, dynamic>> orders) {
    Map<dynamic, Map<String, dynamic>> groupedOrders = {};

    for (var order in orders) {
      final orderId = order['orderId'];

      if (groupedOrders.containsKey(orderId)) {
        final existingOrder = groupedOrders[orderId]!;

        existingOrder['qty'] += double.tryParse(order['qty'].toString()) ?? 0.0;

        existingOrder['realizedPnl'] += double.tryParse(order['realizedPnl'].toString()) ?? 0.0;
        existingOrder['quoteQty'] += double.tryParse(order['quoteQty'].toString()) ?? 0.0;
        existingOrder['commission'] += double.tryParse(order['commission'].toString()) ?? 0.0;
      } else {
        // Create a new entry if orderId doesn't exist
        String flippedSide = order['side'] == 'SELL' ? 'BUY' : 'SELL';
        groupedOrders[orderId] = {
          'symbol': order['symbol'],
          'orderId': orderId,
          'side': flippedSide,
          'price': order['price'],
          'qty': double.tryParse(order['qty'].toString()) ?? 0.0,
          'realizedPnl': double.tryParse(order['realizedPnl'].toString()) ?? 0.0,
          'quoteQty': double.tryParse(order['quoteQty'].toString()) ?? 0.0,
          'commission': double.tryParse(order['commission'].toString()) ?? 0.0,
          'commissionAsset': order['commissionAsset'],
          'time': order['time'],
        };
      }
    }
    return groupedOrders.values.toList();
  }

  void _showUserTradesDialog(BuildContext context) {
    // Set default start and end dates to the current month
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = now;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: binance.getUserTrades(_binanceApiKey, _binanceApiSecret, startDate, endDate),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: CircularProgressIndicator());
                  } else {
                    var fullTrades = snapshot.data!;

                    // Filter trades by date range
                    if (startDate != null && endDate != null) {
                      fullTrades = fullTrades.where((trade) {
                          final tradeDate = DateTime.fromMillisecondsSinceEpoch(trade["time"]);
                          return tradeDate.isAfter(startDate) && tradeDate.isBefore(endDate);
                      }).toList();
                    }

                    var trades = fullTrades;

                    // Calculate total Realized PnL
                    final totalRealizedPnl = trades.fold(
                      0.0,
                      (sum, trade) => sum + (double.tryParse(trade["realizedPnl"].toString()) ?? 0.0),
                    );

                    // Calculate total Realized PnL + commissions
                    final totalRealizedPnlComm = trades.fold(
                      0.0,
                      (sum, trade) => sum + (double.tryParse(trade["realizedPnl"].toString()) ?? 0.0) - (double.tryParse(trade["commission"].toString()) ?? 0.0),
                    );

                    trades = fullTrades
                    .where((trade) => double.parse(trade["realizedPnl"]) != 0.0)
                    .toList();
                    trades.sort((a, b) => b["time"].compareTo(a["time"]));

                    trades = _groupAndTransformOrders(trades);

                    return Center(
                      child: IntrinsicWidth(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 48,
                            maxHeight: MediaQuery.of(context).size.height - 80,
                          ),
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                // Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'User Trades Overview',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),

                                // Date Range Picker Button
                                ElevatedButton(
                                  onPressed: () async {
                                    final DateTimeRange? picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                      initialDateRange: DateTimeRange(start: startDate, end: endDate),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                          startDate = picked.start;

                                          // Ensure that the endDate is the exact current time if it's today
                                          if (picked.end.year == DateTime.now().year &&
                                            picked.end.month == DateTime.now().month &&
                                            picked.end.day == DateTime.now().day) {
                                            // If it's today, set endDate to the exact current time
                                            endDate = DateTime.now();
                                          } else {
                                            // Otherwise, set the endDate to the last moment of the picked end date (11:59:59 PM)
                                            endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                                          }
                                      });
                                    }
                                  },
                                  child: Text(
                                    '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}',
                                  ),
                                ),
                                SizedBox(height: 16),

                                // // Display Total Realized PnL
                                // Text(
                                //   'Total Realized PnL: \$${totalRealizedPnl.toStringAsFixed(4)}',
                                //   style: TextStyle(
                                //     fontSize: 16,
                                //     fontWeight: FontWeight.bold,
                                //     color: totalRealizedPnl >= 0 ? Colors.green : Colors.red,
                                //   ),
                                // ),
                                // SizedBox(height: 16),

                                // // Display Total Realized PnL + commission
                                // Text(
                                //   'Total Realized PnL (with commissions): \$${totalRealizedPnlComm.toStringAsFixed(4)}',
                                //   style: TextStyle(
                                //     fontSize: 16,
                                //     fontWeight: FontWeight.bold,
                                //     color: totalRealizedPnl >= 0 ? Colors.green : Colors.red,
                                //   ),
                                // ),
                                // SizedBox(height: 16),

                                // Trades Table
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: 700),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        columnSpacing: 24,
                                        columns: [
                                          DataColumn(label: Text('Symbol', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Side', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Price', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Quantity', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Realized PnL', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Commission', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Time', style: TextStyle(color: Colors.white))),
                                        ],
                                        rows: trades.map<DataRow>((trade) {
                                            final pnl = double.tryParse(trade["realizedPnl"].toString()) ?? 0.0;
                                            final timestamp = trade["time"] as int;
                                            final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                              DateTime.fromMillisecondsSinceEpoch(timestamp),
                                            );

                                            return DataRow(
                                              cells: [
                                                DataCell(Text(trade["symbol"] as String, style: TextStyle(color: Colors.white))),
                                                DataCell(Text(trade["side"] as String, style: TextStyle(color: Colors.white))),
                                                DataCell(Text(trade["price"].toString(), style: TextStyle(color: Colors.white))),
                                                DataCell(Text(trade["qty"].toStringAsFixed(2), style: TextStyle(color: Colors.white))),
                                                DataCell(
                                                  Text(
                                                    '\$${pnl.toStringAsFixed(4)}',
                                                    style: TextStyle(
                                                      color: pnl >= 0 ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(Text('${trade["commission"].toStringAsFixed(7)} ${trade["commissionAsset"]}',
                                                    style: TextStyle(color: Colors.white),
                                                )),
                                                DataCell(Text(formattedTime, style: TextStyle(color: Colors.white))),
                                              ],
                                            );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  void _handleShowChart(String symbol) {
    setState(() {
        _symbol = symbol;
        _tp = 0.0;
        _sl = 0.0;
        _newTp = 0.0;
        _newSl = 0.0;
        _entryPrice = 0.0;
    });
  }

  void _handleUpdatePortfolio(Portfolio portfolio) {
    setState(() {
        fullOptimizedPortfolio = portfolio;
        optimizedPortfolio = portfolio;
    });
  }

  void _showToast(String message) {
    fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: Colors.grey[600],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(
              width: 30.0,
            ),
            Text(message, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: Duration(seconds: 5),
    );
  }

  Future<Portfolio> _handleTrainPortfolio() async {
    final portfolio = await overmind.trainPortfolio(_overmindApiKey, 10, _maxTradeHorizon, 1.0, 1.0);
    _showToast("Training Complete");
    return portfolio;
  }

  Future<Portfolio> _handleResetPortfolio() async {
    return await overmind.resetPortfolio(_overmindApiKey);
  }

  void _showOptimizedPortfolioDialog(BuildContext context) {
    if (!_isPortfolioDataAvailable()) {
      _showLoadingSnackBar(context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: _openPositionsNotifier,
              builder: (context, openPositions, _) {
                return OptimizedPortfolioDialog(
                  latestPrices: _latestPrices,
                  onSetNewTpSl: _setNewTpSl,
                  onPopulateChart: populateChart,
                  onTrainModel: _trainModel,
                  onTrainPortfolio: _handleTrainPortfolio,
                  onResetPortfolio: _handleResetPortfolio,
                  onResetModel: _resetModel,
                  onTradeHolding: _tradeHolding,
                  // onTradeHolding: (Holding asset) => _tradeHolding(context, asset),
                  onShowChart: _handleShowChart,
                  onFetchPortfolio: _fetchPortfolio,
                  onUpdatePortfolio: _handleUpdatePortfolio,
                  fetchOpenPositions: _fetchOpenPositions,
                  openPositions: openPositions,
                  fullOptimizedPortfolio: fullOptimizedPortfolio,
                  optimizationSettings: _optimizationSettings,
                  onViewPosition: _handleShowChart,
                  onUpdateTakeProfit: _updateTakeProfit,
                  onUpdateStopLoss: _updateStopLoss,
                  onUpdateBoth: _updateBoth,
                  onClose: _closePosition,
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isPortfolioDataAvailable() {
    try {
      return fullOptimizedPortfolio != null && (_openPositions?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }

  void _showLoadingSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Portfolio data is still loading. Please wait.'),
        duration: Duration(seconds: 5),
      ),
    );
  }



  void _showOptimizationSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return OptimizationSettingsModal(
          initialSettings: _optimizationSettings,
          onSettingsChanged: (OptimizationSettings newSettings) {
            setState(() {
                _optimizationSettings = newSettings;
            });
          },
        );
      },
    );
  }

  DataRow _buildDataRow(String asset, int allocation, double riskReward, String takeProfit, String stopLoss, String holdDuration) {
    return DataRow(
      cells: [
        DataCell(Text(asset, style: TextStyle(color: Colors.white))),
        DataCell(Text('\$$allocation', style: TextStyle(color: Colors.white))),
        DataCell(Text(riskReward.toStringAsFixed(2), style: TextStyle(color: Colors.white))),
        DataCell(Text(takeProfit, style: TextStyle(color: Colors.white))),
        DataCell(Text(stopLoss, style: TextStyle(color: Colors.white))),
        DataCell(Text(holdDuration, style: TextStyle(color: Colors.white))),
      ],
    );
  }

  Future<void> _getFreeTierKey() async {
    try {
      String freeTierKey = await overmind.getFreeTierApiKey();
      setState(() {
          _overmindApiKey = freeTierKey;
          _overmindApiKeyController.text = freeTierKey;
      });
      await _secureStorage.write(key: 'overmind_api_key', value: freeTierKey);
    } catch (e) {
      // Handle any errors that might occur when getting the free-tier key
      print('Error getting free-tier key: $e');
      // Optionally show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get free-tier key. Please try again later.')),
      );
    }
  }

  Future<void> _resetPortfolio(BuildContext context) async {
    try {
      // Await the resetPortfolio API call and assign the result to optimizedPortfolio
      final Portfolio result = await overmind.resetPortfolio(_overmindApiKey);

      setState(() {
          fullOptimizedPortfolio = result;
          optimizedPortfolio = result;
      });

      // Show a SnackBar to notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your portfolio has been reset'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      // Handle any error that may occur and show a SnackBar for error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset portfolio: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  List<String> _getSubparSymbols() {
    final holdings = fullOptimizedPortfolio.where((holding) {
        return holding.testingScore < _optimizationSettings.minTestingScore;
    });
    return holdings.map((holding) => holding.instrument as String);
  }

  Future<Portfolio> _resetModel(Holding asset) async {
    final symbol = asset.instrument;
    return await overmind.resetModel(_overmindApiKey, symbol);
  }

  Future<Portfolio> _trainModel(Holding asset) async {
    final symbol = [ asset.instrument ];
    return await overmind.trainSomeModels(_overmindApiKey, 10, _maxTradeHorizon, 1.0, 1.0, symbol);
  }

  Future<void> _resetModels(BuildContext context) async {
    try {
      final symbols = _getSubparSymbols();
      // Await the resetPortfolio API call and assign the result to optimizedPortfolio
      final Portfolio result = await overmind.resetModels(_overmindApiKey, symbols);
      setState(() {
          fullOptimizedPortfolio = result;
          optimizedPortfolio = result;
      });

      // Show a SnackBar to notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subpar models have been reset'),
          backgroundColor: Colors.white,
          // duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.black,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (error) {
      // Handle any error that may occur and show a SnackBar for error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset portfolio: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Future<void> _manualUpdate(BuildContext context) async {
  //   try {
  //     final symbols = optimizedPortfolio.symbols;
  //     await _executePortfolio();

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Your portfolio has been executed'),
  //         backgroundColor: Colors.black,
  //         duration: Duration(seconds: 5),
  //       ),
  //     );
  //   } catch (error) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to execute portfolio: $error'),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 5),
  //       ),
  //     );
  //   }
  // }

  void _showOptimizedPortfolioDrawer() {
    if (!_isPortfolioDataAvailable()) {
      _showLoadingSnackBar(context);
      return;
    }
    _scaffoldKey.currentState!.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        drawerScrimColor: Colors.transparent,
        key: _scaffoldKey,
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(0),
            child: TopMenuBar(
              onTrainPortfolio: () => _showTrainingModal(context, false),
              onTrainModels: () => _showTrainingModal(context, true),
              onOptimizedPortfolio: () => _showOptimizedPortfolioDrawer(),
              onTradeHistory: () => _showUserTradesDialog(context),
              onResetPortfolio: () => _resetPortfolio(context),
              onResetModels: () => _resetModels(context),
              onOptimizationSettings: () => _showOptimizationSettingsModal(context),
              // onManualUpdate: () => _manualUpdate(context),
              onSymbolSelected: _handleSymbolSelected,
              onApiKeys: () => _showApiKeysModal(context),
              onAutoTrade: () => _handleAutoTrade(context),
              symbols: symbols,
              selectedSymbol: _symbol,
            ),
          ),
        ),
        drawer: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Drawer(
              width: constraints.maxWidth * 0.45,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: _openPositionsNotifier,
                    builder: (context, openPositions, _) {
                      return OptimizedPortfolioDialog(
                        latestPrices: _latestPrices,
                        onSetNewTpSl: _setNewTpSl,
                        onPopulateChart: populateChart,
                        onTrainModel: _trainModel,
                        onTrainPortfolio: _handleTrainPortfolio,
                        onResetPortfolio: _handleResetPortfolio,
                        onResetModel: _resetModel,
                        onTradeHolding: _tradeHolding,
                        onShowChart: _handleShowChart,
                        onFetchPortfolio: _fetchPortfolio,
                        onUpdatePortfolio: _handleUpdatePortfolio,
                        fetchOpenPositions: _fetchOpenPositions,
                        openPositions: openPositions,
                        fullOptimizedPortfolio: fullOptimizedPortfolio,
                        optimizationSettings: _optimizationSettings,
                        onViewPosition: _handleShowChart,
                        onUpdateTakeProfit: _updateTakeProfit,
                        onUpdateStopLoss: _updateStopLoss,
                        onUpdateBoth: _updateBoth,
                        onClose: _closePosition,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        body: Center(
          child: Container(
            color: Color(0xFF141218),
            child: candles.length == 0
            ? CircularProgressIndicator()
            : InteractiveChart(
              style: ChartStyle(
                priceGainColor: Colors.white,
                priceLossColor: Colors.black,
                trendLineStyles: [
                  Paint()
                  ..strokeWidth = 2.0
                  ..strokeCap = StrokeCap.round
                  ..color = Colors.deepOrange
                ],
              ),
              candles: candles,
              amheragHeight: _amheragHeight,
              tp: _tp,
              sl: _sl,
              newTp: _newTp,
              newSl: _newSl,
              entryPrice: _entryPrice,
              lastClose: candles?.last.close ?? 0.0,
            ),
          )
        ),
    ));
  }
}
