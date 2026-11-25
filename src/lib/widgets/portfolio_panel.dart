import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/action_result.dart';
import '../domain/open_positions.dart';
import '../domain/portfolio.dart';
import '../domain/trade_settings.dart';
import '../utils/log.dart';
import 'basic.dart';
import 'feedback.dart';
import 'positions.dart';

/// Everything the dashboard can do to the portfolio, the signals and the
/// positions resting on the exchange.
///
/// The panel owns no fetching or polling: the screen supplies these actions so
/// there is a single owner of refresh policy and one place that stores keys.
class PortfolioActions {
  const PortfolioActions({
    required this.trainPortfolio,
    required this.resetPortfolio,
    required this.trainModel,
    required this.resetModel,
    required this.tradeHolding,
    required this.selectSymbol,
    required this.updateTakeProfit,
    required this.updateStopLoss,
    required this.updateBoth,
    required this.closePosition,
  });

  final Future<Portfolio> Function() trainPortfolio;
  final Future<Portfolio> Function() resetPortfolio;
  final Future<Portfolio> Function(Holding holding) trainModel;
  final Future<Portfolio> Function(Holding holding) resetModel;

  /// Opens a position using the allocation and leverage shown in the panel.
  final Future<ActionResult> Function(Holding holding) tradeHolding;

  final ValueChanged<String> selectSymbol;
  final Future<ActionResult> Function(String symbol) updateTakeProfit;
  final Future<ActionResult> Function(String symbol) updateStopLoss;
  final Future<ActionResult> Function(String symbol) updateBoth;
  final Future<ActionResult> Function(String symbol) closePosition;
}

/// The trading dashboard: open positions, trade sizing, portfolio actions and
/// every trained signal the server reports.
class OptimizedPortfolioDialog extends StatefulWidget {
  const OptimizedPortfolioDialog({
    required this.portfolio,
    required this.latestPrices,
    required this.positions,
    required this.actions,
    required this.tradeSettings,
    required this.onTradeSettingsChanged,
    super.key,
  });

  /// All trained signals; the search box narrows what is displayed.
  final Portfolio portfolio;

  /// Latest close per instrument, used to turn offsets into shown prices.
  final Map<String, double> latestPrices;

  final ValueListenable<OpenPositions> positions;
  final PortfolioActions actions;
  final TradeSettings tradeSettings;
  final ValueChanged<TradeSettings> onTradeSettingsChanged;

  /// Timeframe that gets the action buttons and the larger font.
  static const String primaryTimeframe = '5m';

  @override
  State<OptimizedPortfolioDialog> createState() =>
      _OptimizedPortfolioDialogState();
}

class _OptimizedPortfolioDialogState extends State<OptimizedPortfolioDialog> {
  static const double _rowFontSize = 14;
  static const double _auxFontSize = 11;

  final TextEditingController _search = TextEditingController();
  late final TextEditingController _allocation = TextEditingController(
      text: widget.tradeSettings.allocationUsdt.toString());
  late final TextEditingController _leverage =
      TextEditingController(text: widget.tradeSettings.leverage.toString());
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    _allocation.dispose();
    _leverage.dispose();
    super.dispose();
  }

  /// Comma-separated terms, matched case-insensitively against instruments.
  List<Holding> _visibleHoldings() {
    final terms = _query
        .toLowerCase()
        .split(',')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();

    if (terms.isEmpty) return widget.portfolio.holdings;

    return widget.portfolio.holdings.where((holding) {
      return terms
          .any((term) => holding.instrument.toLowerCase().contains(term));
    }).toList();
  }

  /// Runs a portfolio action. [reselect] is the symbol whose levels changed,
  /// so the chart overlay is rebuilt for it; full portfolio actions leave the
  /// selection to the screen, which already knows the current symbol.
  Future<void> _run(Future<Portfolio> Function() action,
      {String? reselect}) async {
    try {
      final portfolio = await action();
      if (!mounted) return;
      if (reselect != null) widget.actions.selectSymbol(reselect);
      log('Portfolio updated: ${portfolio.length} signals');
    } catch (error) {
      if (!mounted) return;
      showToast('${reselect ?? 'Portfolio'} action failed');
      logError('portfolio action', error);
    }
  }

  Future<void> _trade(Holding holding) async {
    final outcome = await widget.actions.tradeHolding(holding);
    if (!mounted) return;
    showToast(outcome.message);
  }

  void _updateAllocation(String value) {
    final allocation = double.tryParse(value);
    if (allocation == null) return;
    widget.onTradeSettingsChanged(
      TradeSettings(
        allocationUsdt: allocation,
        leverage: widget.tradeSettings.leverage,
      ),
    );
  }

  void _updateLeverage(String value) {
    final leverage = int.tryParse(value);
    if (leverage == null) return;
    widget.onTradeSettingsChanged(
      TradeSettings(
        allocationUsdt: widget.tradeSettings.allocationUsdt,
        leverage: leverage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.center,
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PositionsDialog(
                        positions: widget.positions,
                        actions: PositionActions(
                          viewPosition: widget.actions.selectSymbol,
                          updateTakeProfit: widget.actions.updateTakeProfit,
                          updateStopLoss: widget.actions.updateStopLoss,
                          updateBoth: widget.actions.updateBoth,
                          closePosition: widget.actions.closePosition,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _settingsForm(),
                      const SizedBox(height: 8),
                      _trainingButtons(),
                      const SizedBox(height: 8),
                      _searchBar(),
                      const SizedBox(height: 8),
                      _holdingsTable(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _settingsForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          numberFieldRow(
            label: 'Allocation per trade (USDT):',
            controller: _allocation,
            isInteger: false,
            onChanged: _updateAllocation,
          ),
          const SizedBox(height: 16),
          numberFieldRow(
            label: 'Leverage:',
            controller: _leverage,
            isInteger: true,
            onChanged: _updateLeverage,
          ),
        ],
      ),
    );
  }

  Widget _trainingButtons() {
    return Column(
      children: [
        labeledButtonRow(
          label: 'Train Portfolio:',
          buttonText: 'Train Full Portfolio',
          icon: Icons.fitness_center,
          onPressed: () => _run(widget.actions.trainPortfolio),
        ),
        labeledButtonRow(
          label: 'Reset Portfolio:',
          buttonText: 'Reset Full Portfolio',
          icon: Icons.delete,
          buttonColor: Colors.redAccent,
          onPressed: () => _run(widget.actions.resetPortfolio),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Search Assets (comma separated)',
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  Widget _holdingsTable() {
    final holdings = _visibleHoldings();

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: [
            for (final title in _columnTitles)
              DataColumn(
                  label:
                      Text(title, style: const TextStyle(color: Colors.white))),
          ],
          rows: [
            for (final holding in holdings) _holdingRow(holding),
          ],
        ),
      ),
    );
  }

  static const List<String> _columnTitles = [
    'Actions',
    'Asset',
    'Last Trades',
    'μ',
    'α',
    'Dir1',
    'Dir2',
    'Take Profit',
    'Stop Loss',
  ];

  DataRow _holdingRow(Holding holding) {
    final isPrimary =
        holding.timeframe == OptimizedPortfolioDialog.primaryTimeframe;
    final fontSize = isPrimary ? _rowFontSize : _auxFontSize;
    final isOpenPosition =
        widget.positions.value.hasPositionFor(holding.instrument);

    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.grey.withValues(alpha: 0.3);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.grey.withValues(alpha: 0.1);
        }
        if (isOpenPosition) {
          return Colors.lightGreen.withValues(alpha: 0.3);
        }
        return isPrimary ? Colors.grey.withValues(alpha: 0.2) : null;
      }),
      cells: [
        DataCell(isPrimary ? _actionCell(holding) : const SizedBox.shrink()),
        _cell(holding.instrument, fontSize),
        _tradesCell(holding.lastTrades, fontSize),
        _scoreCell(holding.outputScore, 0.60, fontSize),
        _scoreCell(holding.outputActivation, 0.78, fontSize),
        _directionCell(holding.direction1, holding.takeProfit, fontSize),
        _directionCell(holding.direction2, holding.takeProfit, fontSize),
        _priceCell(
            holding.takeProfit, holding.instrument, Colors.green, fontSize),
        _priceCell(holding.stopLoss, holding.instrument, Colors.red, fontSize),
      ],
    );
  }

  Widget _actionCell(Holding holding) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(Icons.visibility, 'Show Chart', Colors.white,
            () => widget.actions.selectSymbol(holding.instrument)),
        _iconButton(
            Icons.paid, 'Trade Asset', Colors.green, () => _trade(holding)),
        _iconButton(
            Icons.fitness_center,
            'Train Asset',
            Colors.blue,
            () => _run(() => widget.actions.trainModel(holding),
                reselect: holding.instrument)),
        _iconButton(
            Icons.delete,
            'Reset Asset',
            Colors.yellow,
            () => _run(() => widget.actions.resetModel(holding),
                reselect: holding.instrument)),
      ],
    );
  }

  Widget _iconButton(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return IconButton(
        icon: Icon(icon, color: color), tooltip: tooltip, onPressed: onPressed);
  }

  DataCell _cell(String text, double fontSize) {
    return DataCell(
        Text(text, style: TextStyle(color: Colors.white, fontSize: fontSize)));
  }

  /// White when the score clears [threshold], red otherwise.
  DataCell _scoreCell(double score, double threshold, double fontSize) {
    final color = score >= threshold ? Colors.white : Colors.red;
    return DataCell(
      Text(score.toStringAsFixed(2),
          style: TextStyle(color: color, fontSize: fontSize)),
    );
  }

  /// White when the direction agrees with the trade side it is recommending.
  DataCell _directionCell(
      double direction, double takeProfit, double fontSize) {
    final color = direction * takeProfit < 0 ? Colors.white : Colors.red;
    return DataCell(
      Text(direction.toStringAsFixed(2),
          style: TextStyle(color: color, fontSize: fontSize)),
    );
  }

  /// Offsets are shown as absolute prices, so the reader sees the level the
  /// order would rest at.
  DataCell _priceCell(
      double offset, String instrument, Color color, double fontSize) {
    final price =
        (offset + (widget.latestPrices[instrument] ?? 0)).toStringAsFixed(7);
    return DataCell(
        Text(price, style: TextStyle(color: color, fontSize: fontSize)));
  }

  /// One bar per closed trade: green for profit, red for loss, taller when the
  /// trade went in the recommended direction.
  DataCell _tradesCell(List<ModelTrade> trades, double fontSize) {
    if (trades.isEmpty) {
      return DataCell(
        Text('No trades',
            style: TextStyle(color: Colors.grey, fontSize: fontSize)),
      );
    }

    return DataCell(
      Row(
        children: [
          for (final trade in trades)
            Expanded(
              child: Container(
                height: trade.direction > 0 ? 16 : 8,
                width: 5,
                decoration: BoxDecoration(
                  color: trade.revenue > 0
                      ? Colors.green
                      : trade.revenue < 0
                          ? Colors.red
                          : Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
