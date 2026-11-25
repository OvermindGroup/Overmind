import 'open_positions.dart';
import 'portfolio.dart';

/// Overlay levels the chart draws for the selected symbol.
///
/// Prices drawn by the painter come in two flavours: the levels resting on the
/// exchange are absolute prices, while the levels the portfolio recommends are
/// offsets added to the last close. Keeping them as separate fields makes that
/// distinction visible.
class ChartState {
  const ChartState({
    this.takeProfitPrice = 0,
    this.stopLossPrice = 0,
    this.plannedTakeProfit = 0,
    this.plannedStopLoss = 0,
    this.auxTakeProfit = 0,
    this.auxStopLoss = 0,
    this.entryPrice = 0,
    this.lastClose = 0,
  });

  static const ChartState none = ChartState();

  /// Absolute prices of the orders currently resting on the exchange.
  final double takeProfitPrice;
  final double stopLossPrice;

  /// Offsets from [lastClose] recommended by the primary timeframe.
  final double plannedTakeProfit;
  final double plannedStopLoss;

  /// Offsets from [lastClose] recommended by the auxiliary timeframe.
  final double auxTakeProfit;
  final double auxStopLoss;

  final double entryPrice;

  /// Close of the newest candle as reported by Overmind.
  final double lastClose;

  /// A short signal is priced off the bid, a long one off the ask.
  bool get preferBid => plannedTakeProfit < 0;

  ChartState copyWith({
    double? takeProfitPrice,
    double? stopLossPrice,
    double? plannedTakeProfit,
    double? plannedStopLoss,
    double? auxTakeProfit,
    double? auxStopLoss,
    double? entryPrice,
    double? lastClose,
  }) {
    return ChartState(
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
      plannedTakeProfit: plannedTakeProfit ?? this.plannedTakeProfit,
      plannedStopLoss: plannedStopLoss ?? this.plannedStopLoss,
      auxTakeProfit: auxTakeProfit ?? this.auxTakeProfit,
      auxStopLoss: auxStopLoss ?? this.auxStopLoss,
      entryPrice: entryPrice ?? this.entryPrice,
      lastClose: lastClose ?? this.lastClose,
    );
  }

  /// Drops every overlay except [lastClose], which belongs to the candle series.
  ChartState cleared() {
    return copyWith(
      takeProfitPrice: 0,
      stopLossPrice: 0,
      plannedTakeProfit: 0,
      plannedStopLoss: 0,
      auxTakeProfit: 0,
      auxStopLoss: 0,
      entryPrice: 0,
    );
  }

  /// Overlays for [symbol]: recommended offsets from the portfolio plus the
  /// absolute levels resting on the exchange, if the symbol is held.
  ///
  /// A holding with no take-profit leaves the recommended offsets at zero, but
  /// resting orders are still reported, matching what the exchange shows.
  ChartState levelsFor(
    String symbol, {
    required Portfolio portfolio,
    required String timeframe,
    required String auxTimeframe,
    required OpenPositions positions,
  }) {
    final holding = portfolio.holdingFor(symbol, timeframe);
    var state = cleared();

    if (holding != null && holding.takeProfit != 0) {
      final aux = portfolio.holdingFor(symbol, auxTimeframe);
      final auxTakeProfit = aux?.takeProfit ?? 0;
      state = state.copyWith(
        plannedTakeProfit: holding.takeProfit,
        plannedStopLoss: holding.stopLoss,
        auxTakeProfit: auxTakeProfit,
        auxStopLoss: auxTakeProfit != 0 ? (aux?.stopLoss ?? 0) : 0,
      );
    }

    final resting = positions.positionFor(symbol);
    if (resting != null) {
      state = state.copyWith(
        takeProfitPrice: resting.takeProfitPrice,
        stopLossPrice: resting.stopLossPrice,
        entryPrice: resting.entryPrice,
      );
    }

    return state;
  }
}
