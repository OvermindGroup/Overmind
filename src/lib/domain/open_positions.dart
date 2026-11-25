import 'account_balance.dart';
import 'exchange.dart';

/// A resting position combined with its take-profit and stop-loss orders.
class PositionSnapshot {
  const PositionSnapshot({
    required this.symbol,
    required this.entryPrice,
    required this.positionAmount,
    required this.takeProfitPrice,
    required this.stopLossPrice,
    required this.takeProfitProgress,
    required this.stopLossProgress,
    required this.unrealizedProfit,
    required this.initialMargin,
  });

  /// Pairs one position with the orders resting on it.
  ///
  /// Order order matters: the first order is whichever the exchange returned
  /// first, so a leading `STOP_MARKET` means the second entry is the take
  /// profit. Progress is how far the current P&L has travelled toward the
  /// level it is heading for — 100 means the level is reached.
  factory PositionSnapshot.from({
    required OpenPosition position,
    required List<OpenOrder> orders,
  }) {
    var takeProfitPrice = 0.0;
    var stopLossPrice = 0.0;
    var takeProfitProgress = 0.0;
    var stopLossProgress = 0.0;

    if (orders.isNotEmpty) {
      final firstPrice = orders.first.triggerPrice;
      final secondPrice = orders.length > 1 ? orders[1].triggerPrice : 0.0;
      if (orders.first.isStopLoss) {
        takeProfitPrice = secondPrice;
        stopLossPrice = firstPrice;
      } else {
        takeProfitPrice = firstPrice;
        stopLossPrice = secondPrice;
      }

      // Notional exposure, i.e. how much the margin controls at the entry price.
      final exposure = position.entryPrice == 0
          ? 0
          : position.initialMargin / position.entryPrice;
      final takeProfitPotential =
          exposure * takeProfitPrice - position.initialMargin;
      final stopLossPotential =
          position.initialMargin - exposure * stopLossPrice;
      final travelled = position.unrealizedProfit.abs();

      if (position.unrealizedProfit > 0 && takeProfitPotential > 0) {
        takeProfitProgress = travelled / takeProfitPotential * 100;
      } else if (position.unrealizedProfit <= 0 && stopLossPotential > 0) {
        stopLossProgress = travelled / stopLossPotential * 100;
      }
    }

    return PositionSnapshot(
      symbol: position.symbol,
      entryPrice: position.entryPrice,
      positionAmount: position.positionAmount,
      takeProfitPrice: takeProfitPrice,
      stopLossPrice: stopLossPrice,
      takeProfitProgress: takeProfitProgress,
      stopLossProgress: stopLossProgress,
      unrealizedProfit: position.unrealizedProfit,
      initialMargin: position.initialMargin,
    );
  }

  final String symbol;
  final double entryPrice;

  /// Negative for shorts.
  final double positionAmount;

  final double takeProfitPrice;
  final double stopLossPrice;

  /// Percentage of the way to the level the position is moving toward.
  final double takeProfitProgress;
  final double stopLossProgress;

  final double unrealizedProfit;
  final double initialMargin;

  bool get isLong => positionAmount > 0;

  /// Signed margin, shown as "+$x" for longs and "-$x" for shorts.
  String get marginLabel =>
      '${isLong ? '+' : '-'}\$${initialMargin.toStringAsFixed(2)}';

  String get profitLabel => '\$${unrealizedProfit.toStringAsFixed(4)}';
}

/// Everything the dashboard shows about the account: balance plus open trades.
class OpenPositions {
  const OpenPositions({
    required this.balance,
    required this.positions,
  });

  static const OpenPositions empty = OpenPositions(
    balance: FuturesBalance.empty,
    positions: [],
  );

  final FuturesBalance balance;
  final List<PositionSnapshot> positions;

  int get count => positions.length;

  bool get isEmpty => positions.isEmpty;

  PositionSnapshot? positionFor(String symbol) {
    for (final position in positions) {
      if (position.symbol == symbol) return position;
    }
    return null;
  }

  bool hasPositionFor(String symbol) => positionFor(symbol) != null;
}
