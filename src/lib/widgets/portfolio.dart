import 'dart:async';
import 'package:flutter/material.dart';
import '../services/overmind_api.dart';
import '../widgets/positions.dart';
import '../widgets/optimization_settings.dart';
import 'package:flutter_sizer/flutter_sizer.dart';
import 'package:collection/collection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OptimizedPortfolioDialog extends StatefulWidget {
  final Map<String, double> latestPrices;
  final Function(String) onSetNewTpSl;
  final Function() onPopulateChart;
  final Future<Portfolio> Function() onTrainPortfolio;
  final Future<Portfolio> Function() onResetPortfolio;
  final Future<Portfolio> Function(Holding) onTrainModel;
  final Future<Portfolio> Function(Holding) onResetModel;
  final Future<void> Function(Holding, double, int) onTradeHolding;
  final Function(String) onShowChart;
  final Future<Portfolio> Function() onFetchPortfolio;
  final Function(Portfolio) onUpdatePortfolio;
  final Future<void> Function() fetchOpenPositions;
  final Map<String, dynamic> openPositions;
  final Portfolio fullOptimizedPortfolio;
  final OptimizationSettings optimizationSettings;
  final Function(String) onViewPosition;
  final Function(BuildContext, String) onUpdateTakeProfit;
  final Function(BuildContext, String) onUpdateStopLoss;
  final Function(BuildContext, String) onUpdateBoth;
  final Function(BuildContext, String) onClose;
  final FlutterSecureStorage storage;
  final String Function() getSymbol;

  const OptimizedPortfolioDialog({
      Key? key,
      required this.latestPrices,
      required this.onFetchPortfolio,
      required this.onSetNewTpSl,
      required this.onPopulateChart,
      required this.onTrainPortfolio,
      required this.onResetPortfolio,
      required this.onTrainModel,
      required this.onResetModel,
      required this.onTradeHolding,
      required this.onShowChart,
      required this.onUpdatePortfolio,
      required this.fetchOpenPositions,
      required this.openPositions,
      required this.fullOptimizedPortfolio,
      required this.optimizationSettings,
      required this.onViewPosition,
      required this.onUpdateTakeProfit,
      required this.onUpdateStopLoss,
      required this.onUpdateBoth,
      required this.onClose,
      required this.storage,
      required this.getSymbol,
  }) : super(key: key);

  @override
  _OptimizedPortfolioDialogState createState() =>
  _OptimizedPortfolioDialogState();
}

class _OptimizedPortfolioDialogState extends State<OptimizedPortfolioDialog> {
  String? _symbol;
  double _tp = 0.0;
  double _sl = 0.0;
  double _newTp = 0.0;
  double _newSl = 0.0;
  double _entryPrice = 0.0;
  late Future<Portfolio> _portfolioFuture;
  late String _searchText;
  final TextEditingController _searchController = TextEditingController();
  // Keep these up to date
  late Future<void> _positionsFuture;
  late Map<String, dynamic> _openPositions;

  final TextEditingController _allocationController = TextEditingController();
  final TextEditingController _leverageController = TextEditingController();
  double _allocationUSDT = 0.0;
  int _leverage = 1;

  late StreamSubscription _portfolioStream;

  @override
  void initState() {
    super.initState();
    _portfolioFuture = widget.onFetchPortfolio();
    _searchText = '';
    _searchController.addListener(() {
        setState(() {
            _searchText = _searchController.text;
        });
    });
    _loadSettings();
    _startPortfolioStream();
    _allocationController.addListener(_updateSettings);
    _leverageController.addListener(_updateSettings);
    // Initialize and fetch initially.
    _fetchOpenPositionsAndUpdateState();
  }

  Future<void> _loadSettings() async {
    String? savedAllocation = await widget.storage.read(key: 'allocationUSDT');
    String? savedLeverage = await widget.storage.read(key: 'leverage');
    if (savedAllocation != null) {
      setState(() {
          _allocationUSDT = double.tryParse(savedAllocation) ?? 0.0;
          _allocationController.text = _allocationUSDT.toString();
      });
    }
    if (savedLeverage != null) {
      setState(() {
          _leverage = int.tryParse(savedLeverage) ?? 0;
          _leverageController.text = _leverage.toString();
      });
    }
  }

  void _startPortfolioStream() {
    _portfolioStream = Stream.periodic(const Duration(seconds: 10)).listen((_) {
        var symbol = widget.getSymbol();
        setState(() {
            _portfolioFuture = widget.onFetchPortfolio().then((portfolio) {
                widget.onUpdatePortfolio(portfolio);
                _handleShowChart(symbol);
                return portfolio;
            });
        });
    });
  }

  Future<void> _saveSettings(double value, int leverage) async {
    await widget.storage.write(key: 'allocationUSDT', value: _allocationUSDT.toString());
    await widget.storage.write(key: 'leverage', value: _leverage.toString());
  }

  void _updateSettings() {
    final allocationUSDT = _allocationController.text;
    final parsedAllocationUSDT = double.tryParse(allocationUSDT);
    final leverage = _leverageController.text;
    final parsedLeverage = int.tryParse(leverage);

    if (parsedAllocationUSDT != null && parsedAllocationUSDT != _allocationUSDT) {
      setState(() {
          _allocationUSDT = parsedAllocationUSDT;
      });
      _saveSettings(_allocationUSDT, _leverage);
    }
    if (parsedLeverage != null && parsedLeverage != _leverage) {
      setState(() {
          _leverage = parsedLeverage;
      });
      _saveSettings(_allocationUSDT, _leverage);
    }
  }

  Future<void> _fetchOpenPositionsAndUpdateState() async {
    // await widget.fetchOpenPositions(); // Fetch new open positions
    setState(() {
        _positionsFuture =  widget.fetchOpenPositions();
        _openPositions = widget.openPositions;
    });
  }

  @override
  void dispose() {
    _allocationController.removeListener(_updateSettings);
    _allocationController.dispose();
    _leverageController.removeListener(_updateSettings);
    _leverageController.dispose();
    _searchController.dispose();
    _portfolioStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.center,
            child: IntrinsicWidth(child: _buildDialogContent(context)),
          );
        },
      ),
    );
  }

  Widget _buildLoadingWidget({required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return FutureBuilder<Portfolio>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        // if (snapshot.connectionState == ConnectionState.waiting) {
        //   return Center(
        //     child: _buildLoadingWidget(message: "Processing. Please wait..."));
        // } else
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(child: Text('No Portfolio Data Available'));
        } else {
          var isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final currentPortfolio = snapshot.data!;
          final filteredPortfolio =
          _filterPortfolio(currentPortfolio, _searchText);
          return SingleChildScrollView(
            child: _buildContainer(context, filteredPortfolio, isWaiting),
          );
        }
      },
    );
  }

  List<Holding> _filterPortfolio(Portfolio currentPortfolio, String query) {
    if (query.isEmpty) {
      return currentPortfolio.holdings;
    } else {
      final searchTerms = query.toLowerCase().split(',').map((term) => term.trim()).where((term) => term.isNotEmpty).toList();

      if (searchTerms.isEmpty) {
        return currentPortfolio.holdings;
      } else {
        return currentPortfolio.holdings.where((asset) {
            return searchTerms.any((term) => asset.instrument.toLowerCase().contains(term));
        }).toList();
      }
    }
  }

  Widget buildLabeledButton({
      required String labelText,
      required String buttonText,
      required IconData icon,
      required VoidCallback onPressed,
      Color? buttonColor, // Optional button color
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              labelText,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon( // Use ElevatedButton for a more prominent look
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white), // White icon for contrast
              label: Text(
                buttonText,
                style: TextStyle(color: Colors.white), // White text for contrast
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor ?? Colors.blue, // Use provided color or default to blue
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 18), // Slightly larger padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // More rounded corners
                ),
                elevation: 5, // Add a subtle shadow
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingButtons() {
    return Column(
      children: [
        buildLabeledButton(
          labelText: 'Train Portfolio:',
          buttonText: 'Train Full Portfolio',
          icon: Icons.fitness_center,
          onPressed: () {
            _handleTrainPortfolio();
          },
        ),
        buildLabeledButton(
          labelText: 'Reset Portfolio:',
          buttonText: 'Reset Full Portfolio',
          icon: Icons.delete,
          onPressed: () {
            _handleResetPortfolio();
          },
          buttonColor: Colors.redAccent,
        ),
      ],
    );
  }

  // Widget _buildTrainPortfolioButton() {
  //   return TextButton.icon(
  //     onPressed: () {
  //       _handleTrainPortfolio();
  //     },
  //     icon: Icon(Icons.fitness_center),
  //     label: Text('Train Full Portfolio'),
  //     style: ButtonStyle(
  //       padding: MaterialStateProperty.all(
  //         EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
  //       shape: MaterialStateProperty.all(
  //         RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildResetPortfolioButton() {
  //   return TextButton.icon(
  //     onPressed: () {
  //       _handleResetPortfolio();
  //     },
  //     icon: Icon(Icons.delete),
  //     label: Text('Reset Full Portfolio'),
  //     style: ButtonStyle(
  //       padding: MaterialStateProperty.all(
  //         EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
  //       shape: MaterialStateProperty.all(
  //         RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSettingsForm() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'Allocation per trade (USDT):',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextFormField(
                    controller: _allocationController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none, // Remove border inside container
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // No need to use onChanged
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.0), // Spacing between rows

        Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'Leverage:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextFormField(
                    controller: _leverageController,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none, // Remove border inside container
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // No need to use onChanged
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildContainer(BuildContext context, List<Holding> filteredPortfolio, bool isWaiting) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // _buildHeader(),
            SizedBox(height: 16),
            PositionsDialog(
              fetchOpenPositions: widget.fetchOpenPositions,
              fetchPortfolio: widget.onFetchPortfolio,
              openPositions: widget.openPositions,
              fullOptimizedPortfolio: widget.fullOptimizedPortfolio,
              optimizationSettings: widget.optimizationSettings,
              onViewPosition: _handleShowChart,
              onUpdateTakeProfit: widget.onUpdateTakeProfit,
              onUpdateStopLoss: widget.onUpdateStopLoss,
              onUpdateBoth: widget.onUpdateBoth,
              onClose: widget.onClose,
            ),
            // SizedBox(height: 8),
            // _buildTrainPortfolioButton(),
            // SizedBox(height: 8),
            // _buildResetPortfolioButton(),
            SizedBox(height: 8),
            _buildSettingsForm(),
            SizedBox(height: 8),
            _buildTrainingButtons(),
            SizedBox(height: 8),
            _buildSearchBar(),
            SizedBox(height: 8),
            isWaiting ? Center(child: _buildLoadingWidget(message: "Updating portfolio. Please wait...")) : SizedBox(height: 16),
            SizedBox(height: 8),
            _buildPortfolioTable(context, filteredPortfolio),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Search Assets (comma separated)',
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildPortfolioTable(BuildContext context, List<Holding> filteredPortfolio) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: _buildTableColumns(),
          rows: _buildTableRows(context, filteredPortfolio),
        ),
    ));
  }

  List<DataColumn> _buildTableColumns() {
    final columnTitles = [
      'Actions',
      'Asset',
      // 'Risk Reward',
      'Training',
      'Testing',
      'Output',
      'Last Trades',
      // 'Allocation (\$)',
      'Take Profit',
      'Stop Loss',
      // 'Hold Duration',
    ];

    return columnTitles.map((title) {
        return DataColumn(
          label: Text(title, style: TextStyle(color: Colors.white)),
        );
    }).toList();
  }

  // widget.openPositions

  List<DataRow> _buildTableRows(BuildContext context, List<Holding> filteredPortfolio) {
    return filteredPortfolio.map((asset) {
        bool isOpenPosition = widget.openPositions['portfolio'].any((map) => map['symbol'] == asset.instrument);
        return DataRow(
          color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.grey.withOpacity(0.3);
              }
              if (states.contains(MaterialState.hovered)) {
                return Colors.grey.withOpacity(0.1);
              }
              if (isOpenPosition) {
                return Colors.lightGreen.withOpacity(0.3); // Color for open positions
              }
              return null; // Default color, typically transparent
          }),
          cells: [
            _buildActionCell(context, asset),
            _buildTextCell(asset.instrument),
            // _buildTextCell(asset.riskReward.toStringAsFixed(2)),
            _buildScoreCell(asset.trainingScore.toStringAsFixed(2), 1.0),
            _buildScoreCell(asset.testingScore.toStringAsFixed(2), 1.0),
            _buildScoreCell(asset.outputScore.toStringAsFixed(2), 0.5),
            _buildListTradesCell(asset.lastTrades),
            // _buildTextCell('\$${asset.allocation.toStringAsFixed(2)}'),
            _buildPriceCell(asset.takeProfit, asset.instrument,
              asset.takeProfit > asset.stopLoss ? true : false),
            _buildPriceCell(asset.stopLoss, asset.instrument,
              asset.takeProfit > asset.stopLoss ? false : true),
            // _buildTextCell(asset.horizonFormatted),
          ],
        );
    }).toList();
  }

  DataCell _buildActionCell(BuildContext context, Holding asset) {
    return DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            Icons.visibility,
            'Show Chart',
            Colors.white,
            () => _handleShowChart(asset.instrument),
          ),
          _buildActionButton(
            Icons.paid,
            'Trade Asset',
            Colors.green,
            () => _handleTradeAsset(context, asset),
          ),
          _buildActionButton(
            Icons.fitness_center,
            'Train Asset',
            Colors.blue,
            () => _handleTrainModel(asset),
          ),
          _buildActionButton(
            Icons.delete,
            'Reset Asset',
            Colors.yellow,
            () => _handleResetModel(asset),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  DataCell _buildTextCell(String text) {
    return DataCell(Text(text, style: TextStyle(color: Colors.white)));
  }

  DataCell _buildScoreCell(String text, double threshold) {
    final color = double.parse(text) >= threshold ? Colors.white : Colors.red;
    return DataCell(Text(text, style: TextStyle(color: color)));
  }

  DataCell _buildListTradesCell(List<dynamic> revenues) {
    if (revenues == null || revenues.isEmpty) {
      return DataCell(Text('No trades', style: TextStyle(color: Colors.grey)));
    }

    List<List<double>> validRevenues = [];
    for (var revenue in revenues) {
      if (revenue is List && revenue.length == 2 && revenue[0] is num && revenue[1] is num) {
        validRevenues.add([revenue[0].toDouble(), revenue[1].toDouble()]);
      } else {
        print('Warning: Invalid revenue type found: $revenue');
      }
    }

    if (validRevenues.isEmpty) {
      return DataCell(Text('No valid trades', style: TextStyle(color: Colors.grey)));
    }

    List<Widget> bars = [];
    for (List<double> tradeData in validRevenues) {
      double revenue = tradeData[0];
      double direction = tradeData[1];

      Color barColor;
      double barHeight;

      if (revenue > 0) {
        barColor = Colors.green;
      } else if (revenue < 0) {
        barColor = Colors.red;
      } else {
        barColor = Colors.grey;
      }

      if (direction > 0) {
        barHeight = 16.0;
      } else {
        barHeight = 8.0;
      }

      bars.add(
        Expanded(
          flex: 1,
          child: Container(
            height: barHeight,
            width: 5,
            margin: EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return DataCell(
      Row(
        children: bars,
      ),
    );
  }

  DataCell _buildPriceCell(double price, String instrument, bool isTakeProfit) {
    final basePrice = widget.latestPrices[instrument] ?? 0.0;
    final displayPrice = (price + basePrice).toStringAsFixed(7);
    final color = isTakeProfit ? Colors.green : Colors.red;

    return DataCell(Text(displayPrice, style: TextStyle(color: color)));
  }

  void _handleTradeAsset(BuildContext context, Holding asset) {
    widget.onTradeHolding(asset, _allocationUSDT, _leverage);
  }

  void _handleTrainPortfolio() async {
    var symbol = widget.getSymbol();
    setState(() {
        _portfolioFuture = widget.onTrainPortfolio().then((portfolio) {
            widget.onUpdatePortfolio(portfolio);
            _handleShowChart(symbol);
            return portfolio;
        });
    });
  }

  void _handleResetPortfolio() async {
    var symbol = widget.getSymbol();
    setState(() {
        _portfolioFuture = widget.onResetPortfolio().then((portfolio) {
            widget.onUpdatePortfolio(portfolio);
            _handleShowChart(symbol);
            return portfolio;
        });
    });
  }

  void _handleTrainModel(Holding asset) async {
    setState(() {
        _portfolioFuture = widget.onTrainModel(asset).then((portfolio) {
            widget.onUpdatePortfolio(portfolio);
            _handleShowChart(asset.instrument);
            return portfolio;
        });
    });
  }

  void _handleResetModel(Holding asset) async {
    setState(() {
        _portfolioFuture = widget.onResetModel(asset).then((portfolio) {
            widget.onUpdatePortfolio(portfolio);
            _handleShowChart(asset.instrument);
            return portfolio;
        });
    });
  }

  void _handleShowChart(String symbol) async {
    widget.onShowChart(symbol);
    widget.onSetNewTpSl(symbol);
    widget.onPopulateChart();
  }
}
