import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/action_result.dart';
import '../domain/open_positions.dart';

/// Actions available on a resting position. Each takes the symbol and reports
/// what the exchange did, so the caller can show the result.
class PositionActions {
  const PositionActions({
    required this.viewPosition,
    required this.updateTakeProfit,
    required this.updateStopLoss,
    required this.updateBoth,
    required this.closePosition,
  });

  final ValueChanged<String> viewPosition;
  final Future<ActionResult> Function(String symbol) updateTakeProfit;
  final Future<ActionResult> Function(String symbol) updateStopLoss;
  final Future<ActionResult> Function(String symbol) updateBoth;
  final Future<ActionResult> Function(String symbol) closePosition;
}

/// Open positions and account balance, driven by the position tracker.
class PositionsDialog extends StatelessWidget {
  const PositionsDialog(
      {required this.positions, required this.actions, super.key});

  final ValueListenable<OpenPositions> positions;
  final PositionActions actions;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OpenPositions>(
      valueListenable: positions,
      builder: (context, snapshot, _) {
        final sorted = [...snapshot.positions]
          ..sort((a, b) => b.unrealizedProfit.compareTo(a.unrealizedProfit));

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PositionsTable(positions: sorted, actions: actions),
            ),
            const SizedBox(width: 16),
            _BalanceCard(snapshot),
          ],
        );
      },
    );
  }
}

class _PositionsTable extends StatelessWidget {
  const _PositionsTable({required this.positions, required this.actions});

  final List<PositionSnapshot> positions;
  final PositionActions actions;

  static const List<String> _titles = [
    'Actions',
    'Symbol',
    'TP Filled %',
    'SL Filled %',
    'Profit',
    'Margin',
  ];

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No open positions to display',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: [
            for (final title in _titles)
              DataColumn(
                label: Text(title, style: const TextStyle(color: Colors.white)),
              ),
          ],
          rows: [
            for (final position in positions)
              DataRow(
                cells: [
                  DataCell(_ActionButtons(position.symbol, actions)),
                  DataCell(
                    Text(position.symbol,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  DataCell(_ProgressBar(position.takeProfitProgress,
                      isTakeProfit: true)),
                  DataCell(_ProgressBar(position.stopLossProgress,
                      isTakeProfit: false)),
                  DataCell(_ProfitText(position.unrealizedProfit)),
                  DataCell(
                    Text(
                      position.marginLabel,
                      style: TextStyle(
                        color: position.isLong ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons(this.symbol, this.actions);

  final String symbol;
  final PositionActions actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.visibility, 'View Position', Colors.white,
            () => actions.viewPosition(symbol)),
        _button(Icons.trending_up, 'Update TP', Colors.blue,
            () => actions.updateTakeProfit(symbol)),
        _button(Icons.trending_down, 'Update SL', Colors.orange,
            () => actions.updateStopLoss(symbol)),
        _button(Icons.edit, 'Update Both', Colors.green,
            () => actions.updateBoth(symbol)),
        _button(Icons.cancel, 'Close Position', Colors.red,
            () => actions.closePosition(symbol)),
      ],
    );
  }

  Widget _button(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Fill of a resting level: 0 means untouched, 1 means the level is reached.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.progress, {required this.isTakeProfit});

  final double progress;
  final bool isTakeProfit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotatedBox(
        // Take-profit runs away from the entry on one side, stop-loss on the
        // other, so the bar is rotated for the take-profit only.
        quarterTurns: isTakeProfit ? 2 : 0,
        child: LinearProgressIndicator(
          value: (progress / 100).clamp(0, 1),
          minHeight: 20,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            isTakeProfit ? Colors.blue : Colors.red,
          ),
        ),
      ),
    );
  }
}

class _ProfitText extends StatelessWidget {
  const _ProfitText(this.profit);

  final double profit;

  @override
  Widget build(BuildContext context) {
    return Text(
      '\$${profit.toStringAsFixed(4)}',
      style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.snapshot);

  final OpenPositions snapshot;

  @override
  Widget build(BuildContext context) {
    final balance = snapshot.balance;
    final profitColor =
        balance.unrealizedProfit >= 0 ? Colors.green : Colors.red;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Card(
          color: Colors.grey[800],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Total Balance:', balance.totalFormatted, Colors.white),
                  const SizedBox(height: 4),
                  _row('Available Balance:', balance.availableFormatted,
                      Colors.white),
                  const SizedBox(height: 4),
                  _row('Unrealized Profit:', balance.profitFormatted,
                      profitColor),
                  const SizedBox(height: 4),
                  _row('Open Positions:', '${snapshot.count}', Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 10),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
