import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/trades.dart';
import 'pnl_chart.dart';

/// Reads the fills for one date window from Binance.
typedef TradeFetcher = Future<List<TradeFill>> Function(
    DateTime start, DateTime end);

/// Realized P&L, fees and accuracy for a date window, with the trade table.
class TradeHistoryDialog extends StatefulWidget {
  const TradeHistoryDialog({required this.fetchTrades, super.key});

  final TradeFetcher fetchTrades;

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  State<TradeHistoryDialog> createState() => _TradeHistoryDialogState();
}

class _TradeHistoryDialogState extends State<TradeHistoryDialog> {
  static const double _wideWidth = 600;

  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _end = DateTime.now();
  late Future<List<TradeFill>> _fills = widget.fetchTrades(_start, _end);

  /// Re-reads the window. The future is rebuilt here rather than inside
  /// `FutureBuilder`, which would refetch on every parent rebuild.
  void _load() {
    setState(() => _fills = widget.fetchTrades(_start, _end));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked == null) return;

    final today = DateTime.now();
    final endsToday = picked.end.year == today.year &&
        picked.end.month == today.month &&
        picked.end.day == today.day;

    setState(() {
      _start = picked.start;
      // A range that ends today must run to "now", not to the start of the day,
      // otherwise today's trades disappear.
      _end = endsToday
          ? today
          : DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<List<TradeFill>>(
        future: _fills,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _panel(context, child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return _panel(context, child: const CircularProgressIndicator());
          }

          final summary = TradeSummary.analyse(
            snapshot.data!,
            from: _start,
            to: _end,
          );

          return _panel(
            context,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Trades Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                _wide(
                  ElevatedButton(
                    onPressed: _pickRange,
                    child: Text(
                      '${TradeHistoryDialog._dayFormat.format(_start)} to '
                      '${TradeHistoryDialog._dayFormat.format(_end)}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _wide(
                  SizedBox(
                    height: 300,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PnLChart(summary.curve),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _wide(
                  _stat(
                    'P&L: ${_money(summary.totalPnl)}',
                    summary.totalPnl >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                _wide(
                  _stat(
                    'P&L (with commissions): ${_money(summary.totalPnlAfterFees)}',
                    summary.totalPnlAfterFees >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                _wide(
                  _stat(
                    'Accuracy: ${summary.accuracy.toStringAsFixed(2)}% '
                    '(${summary.winningTrades}/${summary.tradeCount})',
                    summary.accuracy >= 55 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                _TradesTable(trades: summary.trades),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panel(BuildContext context, {required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(0, 1000),
          maxHeight: MediaQuery.sizeOf(context).height - 80,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  Widget _wide(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _wideWidth),
        child: child,
      ),
    );
  }

  static String _money(double value) => '\$${value.toStringAsFixed(4)}';

  Widget _stat(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
      textAlign: TextAlign.center,
    );
  }
}

class _TradesTable extends StatelessWidget {
  const _TradesTable({required this.trades});

  final List<ClosedTrade> trades;

  static const List<String> _titles = [
    'Symbol',
    'Side',
    'Price',
    'Quantity',
    'Realized PnL',
    'Commission',
    'Time',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 24,
            columns: [
              for (final title in _titles)
                DataColumn(
                    label: Text(title,
                        style: const TextStyle(color: Colors.white))),
            ],
            rows: [
              for (final trade in trades)
                DataRow(
                  cells: [
                    _cell(trade.symbol),
                    _cell(trade.side),
                    _cell(trade.price.toString()),
                    _cell(trade.quantity.toStringAsFixed(2)),
                    DataCell(
                      Text(
                        '\$${trade.realizedPnl.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: trade.realizedPnl >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    _cell(
                        '${trade.commission.toStringAsFixed(7)} ${trade.commissionAsset}'),
                    _cell(
                        TradeHistoryDialog._timestampFormat.format(trade.time)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _cell(String text) =>
      DataCell(Text(text, style: const TextStyle(color: Colors.white)));
}
