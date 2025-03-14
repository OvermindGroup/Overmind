import 'package:flutter/material.dart';
import '../services/overmind_api.dart';
import '../widgets/optimization_settings.dart';

class PositionData {
  final String symbol;
  final double unrealizedProfit;
  final double tpDistance;
  final double slDistance;
  final double initialMargin;
  final double testingScore;
  final double outputScore;
  final double riskReward;

  PositionData({
      required this.symbol,
      required this.unrealizedProfit,
      required this.tpDistance,
      required this.slDistance,
      required this.initialMargin,
      required this.testingScore,
      required this.outputScore,
      required this.riskReward,
  });

  factory PositionData.fromJson(Map<String, dynamic> json, Holding optimizedHolding) {
    return PositionData(
      symbol: json['symbol'] as String,
      unrealizedProfit: double.tryParse(json['unRealizedProfit'].toString()) ?? 0.0,
      tpDistance: double.tryParse(json['tpDistance'].toString()) ?? 0.0,
      slDistance: double.tryParse(json['slDistance'].toString()) ?? 0.0,
      initialMargin: double.tryParse(json['initialMargin'].toString()) ?? 0.0,
      testingScore: optimizedHolding.testingScore,
      outputScore: optimizedHolding.outputScore,
      riskReward: optimizedHolding.riskReward,
    );
  }
}

class PortfolioOverview {
  final double totalBalance;
  final double availableBalance;
  final double unrealizedProfit;
  final List<PositionData> positions;

  PortfolioOverview({
      required this.totalBalance,
      required this.availableBalance,
      required this.unrealizedProfit,
      required this.positions,
  });
}

class PositionsDialog extends StatefulWidget {
  final Future<void> Function() fetchOpenPositions;
  final Future<void> Function() fetchPortfolio;
  final Map<String, dynamic> openPositions;
  final Portfolio fullOptimizedPortfolio;
  final OptimizationSettings optimizationSettings;
  final Function(String) onViewPosition;
  final Function(BuildContext, String) onUpdateTakeProfit;
  final Function(BuildContext, String) onUpdateStopLoss;
  final Function(BuildContext, String) onUpdateBoth;
  final Function(BuildContext, String) onClose;

  const PositionsDialog({
      Key? key,
      required this.fetchOpenPositions,
      required this.fetchPortfolio,
      required this.openPositions,
      required this.fullOptimizedPortfolio,
      required this.optimizationSettings,
      required this.onViewPosition,
      required this.onUpdateTakeProfit,
      required this.onUpdateStopLoss,
      required this.onUpdateBoth,
      required this.onClose,
  }) : super(key: key);

  @override
  _PositionsDialogState createState() => _PositionsDialogState();
}

class _PositionsDialogState extends State<PositionsDialog> {
  @override
  Widget build(BuildContext context) {
    return _PositionsDialogContent(
      openPositions: widget.openPositions,
      fullOptimizedPortfolio: widget.fullOptimizedPortfolio,
      optimizationSettings: widget.optimizationSettings,
      onViewPosition: widget.onViewPosition,
      onUpdateTakeProfit: widget.onUpdateTakeProfit,
      onUpdateStopLoss: widget.onUpdateStopLoss,
      onUpdateBoth: widget.onUpdateBoth,
      onClose: widget.onClose,
    );
  }
}


class _PositionsDialogContent extends StatefulWidget {
  final Map<String, dynamic> openPositions;
  final Portfolio fullOptimizedPortfolio;
  final OptimizationSettings optimizationSettings;
  final Function(String) onViewPosition;
  final Function(BuildContext, String) onUpdateTakeProfit;
  final Function(BuildContext, String) onUpdateStopLoss;
  final Function(BuildContext, String) onUpdateBoth;
  final Function(BuildContext, String) onClose;

  const _PositionsDialogContent({
      Key? key,
      required this.openPositions,
      required this.fullOptimizedPortfolio,
      required this.optimizationSettings,
      required this.onViewPosition,
      required this.onUpdateTakeProfit,
      required this.onUpdateStopLoss,
      required this.onUpdateBoth,
      required this.onClose,
  }) : super(key: key);

  @override
  _PositionsDialogContentState createState() => _PositionsDialogContentState();
}

class _PositionsDialogContentState extends State<_PositionsDialogContent> {
  @override
  Widget build(BuildContext context) {
    final portfolio = _buildPortfolioOverview(widget.openPositions);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PositionsTable(
            positions: portfolio.positions,
            optimizationSettings: widget.optimizationSettings,
            onViewPosition: widget.onViewPosition,
            onUpdateTakeProfit: widget.onUpdateTakeProfit,
            onUpdateStopLoss: widget.onUpdateStopLoss,
            onUpdateBoth: widget.onUpdateBoth,
            onClose: widget.onClose,
          ),
        ),
        const SizedBox(width: 16),
        _BalanceInfoSection(
          totalBalance: portfolio.totalBalance,
          availableBalance: portfolio.availableBalance,
          unrealizedProfit: portfolio.unrealizedProfit,
          positionsCount: portfolio.positions.length,
        ),
      ],
    );
  }

  PortfolioOverview _buildPortfolioOverview(Map<String, dynamic> openPositions) {
    final positions = (openPositions['portfolio'] as List<dynamic>)
    .map((position) => PositionData.fromJson(
        position,
        widget.fullOptimizedPortfolio.getHolding(position['symbol']),
    ))
    .toList()
    ..sort((a, b) => b.unrealizedProfit.compareTo(a.unrealizedProfit));

    return PortfolioOverview(
      totalBalance: openPositions['totalBalance'] as double,
      availableBalance: openPositions['availableBalance'] as double,
      unrealizedProfit: openPositions['unRealizedProfit'] as double,
      positions: positions,
    );
  }
}


class _BalanceInfoSection extends StatelessWidget {
  final double totalBalance;
  final double availableBalance;
  final double unrealizedProfit;
  final int positionsCount;

  const _BalanceInfoSection({
      required this.totalBalance,
      required this.availableBalance,
      required this.unrealizedProfit,
      required this.positionsCount,
  });

  @override
  Widget build(BuildContext context) {
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
                  _buildBalanceRow('Total Balance:', totalBalance),
                  SizedBox(height: 4),
                  _buildBalanceRow('Available Balance:', availableBalance),
                  SizedBox(height: 4),
                  _buildBalanceRow('Unrealized Profit:', unrealizedProfit),
                  SizedBox(height: 4),
                  _buildBalanceRow('Open Positions:', positionsCount, isCount: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, dynamic value, {bool isCount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isCount ? value.toString() : '\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                color: label.contains('Profit')
                ? (value >= 0 ? Colors.green : Colors.red)
                : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionsTable extends StatelessWidget {
  final List<PositionData> positions;
  final OptimizationSettings optimizationSettings;
  final Function(String) onViewPosition;
  final Function(BuildContext, String) onUpdateTakeProfit;
  final Function(BuildContext, String) onUpdateStopLoss;
  final Function(BuildContext, String) onUpdateBoth;
  final Function(BuildContext, String) onClose;

  const _PositionsTable({
      required this.positions,
      required this.optimizationSettings,
      required this.onViewPosition,
      required this.onUpdateTakeProfit,
      required this.onUpdateStopLoss,
      required this.onUpdateBoth,
      required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: _buildColumns(),
          rows: positions.map((position) => _buildRow(context, position)).toList(),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return const [
      DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white))),
      DataColumn(label: Text('Symbol', style: TextStyle(color: Colors.white))),
      DataColumn(label: Text('TP Filled %', style: TextStyle(color: Colors.white))),
      DataColumn(label: Text('SL Filled %', style: TextStyle(color: Colors.white))),
      DataColumn(label: Text('Profit', style: TextStyle(color: Colors.white))),
      // DataColumn(label: Text('New Risk Reward', style: TextStyle(color: Colors.white))),
      // DataColumn(label: Text('New Testing Score', style: TextStyle(color: Colors.white))),
      // DataColumn(label: Text('New Output Score', style: TextStyle(color: Colors.white))),
      DataColumn(label: Text('Margin', style: TextStyle(color: Colors.white))),
    ];
  }

  DataRow _buildRow(BuildContext context, PositionData position) {
    return DataRow(
      cells: [
        DataCell(_buildActionButtons(context, position.symbol)),
        DataCell(Text(position.symbol, style: const TextStyle(color: Colors.white))),
        DataCell(_buildProgressIndicator(position.tpDistance, true)),
        DataCell(_buildProgressIndicator(position.slDistance, false)),
        DataCell(_buildProfitText(position.unrealizedProfit)),
        // DataCell(_buildScoreText(
        //   position.riskReward.toStringAsFixed(2),
        //   position.riskReward <= optimizationSettings.minRiskReward ||
        //       position.riskReward >= optimizationSettings.maxRiskReward,
        // )),
        // DataCell(_buildScoreText(
        //   position.testingScore.toStringAsFixed(2),
        //   position.testingScore <= optimizationSettings.minTestingScore,
        // )),
        // DataCell(_buildScoreText(
        //   position.outputScore.toStringAsFixed(2),
        //   position.outputScore <= optimizationSettings.minOutputScore,
        // )),
        DataCell(Text(
            '\$${position.initialMargin.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white),
        )),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, String symbol) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility, color: Colors.white),
          tooltip: 'View Position',
          onPressed: () => onViewPosition(symbol),
        ),
        IconButton(
          icon: const Icon(Icons.trending_up, color: Colors.blue),
          tooltip: 'Update TP',
          onPressed: () => onUpdateTakeProfit(context, symbol),
        ),
        IconButton(
          icon: const Icon(Icons.trending_down, color: Colors.orange),
          tooltip: 'Update SL',
          onPressed: () => onUpdateStopLoss(context, symbol),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.green),
          tooltip: 'Update Both',
          onPressed: () => onUpdateBoth(context, symbol),
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          tooltip: 'Close Position',
          onPressed: () => onClose(context, symbol),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double distance, bool isTP) {
    return Center(
      child: RotatedBox(
        quarterTurns: isTP ? 2 : 0,
        child: LinearProgressIndicator(
          value: 1.0 - (distance / 100),
          minHeight: 20,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            distance > 60.0 ? Colors.red : Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildProfitText(double profit) {
    return Text(
      '\$${profit.toStringAsFixed(4)}',
      style: TextStyle(
        color: profit >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildScoreText(String text, bool isWarning) {
    return Text(
      text,
      style: TextStyle(
        color: isWarning ? Colors.red : Colors.white,
      ),
    );
  }
}
