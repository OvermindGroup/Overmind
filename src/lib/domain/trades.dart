/// One fill reported by `/fapi/v1/userTrades`. Several fills can share one
/// order id when an order is matched in parts.
class TradeFill {
  const TradeFill({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.price,
    required this.quantity,
    required this.realizedPnl,
    required this.quoteQuantity,
    required this.commission,
    required this.commissionAsset,
    required this.time,
  });

  final String orderId;
  final String symbol;
  final String side;
  final double price;
  final double quantity;
  final double realizedPnl;
  final double quoteQuantity;
  final double commission;
  final String commissionAsset;
  final DateTime time;

  factory TradeFill.fromApi(Map<String, dynamic> json) {
    return TradeFill(
      orderId: json['orderId']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      price: _asDouble(json['price']),
      quantity: _asDouble(json['qty']),
      realizedPnl: _asDouble(json['realizedPnl']),
      quoteQuantity: _asDouble(json['quoteQty']),
      commission: _asDouble(json['commission']),
      commissionAsset: json['commissionAsset']?.toString() ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(_asInt(json['time'])),
    );
  }
}

/// The closing leg of a position: partial fills sharing one order id are merged,
/// and the commission charged when the position was opened is carried onto it.
class ClosedTrade {
  const ClosedTrade({
    required this.symbol,
    required this.orderId,
    required this.side,
    required this.price,
    required this.quantity,
    required this.realizedPnl,
    required this.commission,
    required this.commissionAsset,
    required this.time,
  });

  final String symbol;
  final String orderId;

  /// Direction of the closing leg, i.e. the opposite of the opening side.
  final String side;

  final double price;
  final double quantity;
  final double realizedPnl;
  final double commission;
  final String commissionAsset;
  final DateTime time;
}

/// A point on the cumulative P&L curve, indexed by trade order.
class PnlPoint {
  const PnlPoint(
      {required this.index, required this.cumulative, required this.time});

  final int index;
  final double cumulative;
  final DateTime time;
}

/// Stats for a date window, computed once and shared by the chart and the table.
class TradeSummary {
  const TradeSummary({
    required this.trades,
    required this.curve,
    required this.totalPnl,
    required this.totalPnlAfterFees,
    required this.winningTrades,
  });

  /// Most recent first, as the table shows them.
  final List<ClosedTrade> trades;

  /// Oldest first, so the chart line runs forward in time.
  final List<PnlPoint> curve;

  final double totalPnl;
  final double totalPnlAfterFees;
  final int winningTrades;

  int get tradeCount => trades.length;

  double get accuracy => tradeCount == 0 ? 0 : winningTrades / tradeCount * 100;

  /// Merge partial fills into closing legs, carry opening commissions onto them,
  /// then total and curve the result.
  static TradeSummary analyse(
    List<TradeFill> fills, {
    DateTime? from,
    DateTime? to,
  }) {
    final windowed = (from == null || to == null)
        ? fills
        : fills
            .where((fill) => fill.time.isAfter(from) && fill.time.isBefore(to))
            .toList();

    final legs = _mergeByOrderId(windowed);
    legs.sort((a, b) {
      final bySymbol = a.symbol.compareTo(b.symbol);
      return bySymbol != 0 ? bySymbol : a.time.compareTo(b.time);
    });

    final closedTrades = _carryOpeningCommission(legs);

    var totalPnl = 0.0;
    var totalPnlAfterFees = 0.0;
    var winningTrades = 0;
    for (final trade in closedTrades) {
      totalPnl += trade.realizedPnl;
      totalPnlAfterFees += trade.realizedPnl - trade.commission;
      if (trade.realizedPnl > 0) winningTrades++;
    }

    final oldestFirst = [...closedTrades]
      ..sort((a, b) => a.time.compareTo(b.time));

    var cumulative = 0.0;
    final curve = <PnlPoint>[];
    for (var i = 0; i < oldestFirst.length; i++) {
      cumulative += oldestFirst[i].realizedPnl;
      curve.add(PnlPoint(
        index: i,
        cumulative: cumulative,
        time: oldestFirst[i].time,
      ));
    }

    final newestFirst = [...closedTrades]
      ..sort((a, b) => b.time.compareTo(a.time));

    return TradeSummary(
      trades: newestFirst,
      curve: curve,
      totalPnl: totalPnl,
      totalPnlAfterFees: totalPnlAfterFees,
      winningTrades: winningTrades,
    );
  }

  /// One merged leg per order id. `side` is flipped so the merged row reads as
  /// the leg that closed the position.
  static List<ClosedTrade> _mergeByOrderId(List<TradeFill> fills) {
    final byOrderId = <String, ClosedTrade>{};

    for (final fill in fills) {
      final existing = byOrderId[fill.orderId];
      if (existing != null) {
        byOrderId[fill.orderId] = ClosedTrade(
          symbol: existing.symbol,
          orderId: existing.orderId,
          side: existing.side,
          price: existing.price,
          quantity: existing.quantity + fill.quantity,
          realizedPnl: existing.realizedPnl + fill.realizedPnl,
          commission: existing.commission + fill.commission,
          commissionAsset: existing.commissionAsset,
          time: existing.time,
        );
        continue;
      }

      byOrderId[fill.orderId] = ClosedTrade(
        symbol: fill.symbol,
        orderId: fill.orderId,
        side: fill.side == 'SELL' ? 'BUY' : 'SELL',
        price: fill.price,
        quantity: fill.quantity,
        realizedPnl: fill.realizedPnl,
        commission: fill.commission,
        commissionAsset: fill.commissionAsset,
        time: fill.time,
      );
    }

    return byOrderId.values.toList();
  }

  /// Binance charges the taker fee on the opening leg, where realized P&L is
  /// zero. Move those fees onto the closing leg so the displayed cost of a
  /// round trip is complete, then keep only the closing legs.
  static List<ClosedTrade> _carryOpeningCommission(List<ClosedTrade> legs) {
    final pendingCommission = <String, double>{};
    final closedTrades = <ClosedTrade>[];

    for (final leg in legs) {
      if (leg.realizedPnl == 0) {
        pendingCommission[leg.symbol] =
            (pendingCommission[leg.symbol] ?? 0) + leg.commission;
        continue;
      }

      final carried = pendingCommission[leg.symbol] ?? 0;
      if (carried > 0) {
        pendingCommission[leg.symbol] = 0;
        closedTrades.add(ClosedTrade(
          symbol: leg.symbol,
          orderId: leg.orderId,
          side: leg.side,
          price: leg.price,
          quantity: leg.quantity,
          realizedPnl: leg.realizedPnl,
          commission: leg.commission + carried,
          commissionAsset: leg.commissionAsset,
          time: leg.time,
        ));
      } else {
        closedTrades.add(leg);
      }
    }

    return closedTrades;
  }
}

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
