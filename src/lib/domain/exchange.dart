/// Exchange-facing read models derived from Binance payloads.
///
/// They live in the domain layer so services and widgets never pass
/// `Map<String, dynamic>` around, while the parsing stays next to the wire
/// format that produced them.
library;

/// A futures position with a non-zero amount. Flat rows that
/// `/fapi/v3/positionRisk` returns for every tradable symbol are dropped:
/// they are not positions, and treating them as one blocks new trades.
class OpenPosition {
  const OpenPosition({
    required this.symbol,
    required this.entryPrice,
    required this.positionAmount,
    required this.unrealizedProfit,
    required this.initialMargin,
  });

  final String symbol;
  final double entryPrice;

  /// Negative for shorts.
  final double positionAmount;
  final double unrealizedProfit;
  final double initialMargin;

  static OpenPosition? tryFrom(Map<String, dynamic> json) {
    final amount = _asDouble(json['positionAmt']);
    if (amount == 0) return null;
    return OpenPosition(
      symbol: json['symbol']?.toString() ?? '',
      entryPrice: _asDouble(json['entryPrice']),
      positionAmount: amount,
      unrealizedProfit: _asDouble(json['unRealizedProfit']),
      initialMargin: _asDouble(json['initialMargin']),
    );
  }
}

/// A conditional order resting on the exchange.
///
/// The futures REST endpoint and the algo-order endpoint name the same fields
/// differently (`type`/`orderType`, `triggerPrice`/`stopPrice`,
/// `orderId`/`algoId`, `origQty`/`quantity`), so both spellings are accepted.
class OpenOrder {
  const OpenOrder({
    required this.orderId,
    required this.type,
    required this.side,
    required this.quantity,
    required this.triggerPrice,
  });

  final String orderId;
  final String type;
  final String side;
  final String quantity;
  final double triggerPrice;

  bool get isTakeProfit => type == 'TAKE_PROFIT_MARKET';

  bool get isStopLoss => type == 'STOP_MARKET';

  static OpenOrder? tryFrom(Map<String, dynamic> json) {
    final orderId = json['orderId'] ?? json['algoId'];
    final type = json['type'] ?? json['orderType'];
    if (orderId == null || type == null) return null;
    final quantity = json['origQty'] ?? json['quantity'];
    return OpenOrder(
      orderId: orderId.toString(),
      type: type.toString(),
      side: json['side']?.toString() ?? '',
      quantity: quantity?.toString() ?? '',
      triggerPrice: _asDouble(json['triggerPrice'] ?? json['stopPrice']),
    );
  }
}

/// Whether an order request reached the exchange in the state we asked for.
///
/// `accepted` describes the order status, not the HTTP transport, so callers do
/// not have to compare raw status codes.
class OrderOutcome {
  const OrderOutcome({
    required this.accepted,
    required this.status,
    this.message = '',
  });

  final bool accepted;
  final String status;
  final String message;

  /// A request that never reached the exchange.
  static OrderOutcome rejected(String message) =>
      OrderOutcome(accepted: false, status: '', message: message);

  static OrderOutcome canceled(Map<String, dynamic> json) => OrderOutcome(
        accepted: json['status'] == 'CANCELED',
        status: json['status']?.toString() ?? '',
        message: json['msg']?.toString() ?? '',
      );

  static OrderOutcome created(Map<String, dynamic> json) => OrderOutcome(
        accepted: json['status'] == 'NEW' || json['status'] == 'FILLED',
        status: json['status']?.toString() ?? '',
        message: json['msg']?.toString() ?? '',
      );

  /// Algo orders report `algoStatus` instead of `status`.
  static OrderOutcome createdAlgo(Map<String, dynamic> json) => OrderOutcome(
        accepted: json['algoStatus'] == 'NEW',
        status: json['algoStatus']?.toString() ?? '',
        message: json['msg']?.toString() ?? '',
      );

  static OrderOutcome bulkCanceled(Map<String, dynamic> json) => OrderOutcome(
        accepted: (json['code'] as num? ?? 200) == 200,
        status: json['code']?.toString() ?? '',
        message: json['msg']?.toString() ?? '',
      );
}

/// Tick and lot sizing for one symbol, from `/fapi/v1/exchangeInfo`.
class SymbolPrecision {
  const SymbolPrecision({
    required this.pricePrecision,
    required this.quantityPrecision,
    required this.minQuantity,
    required this.minNotional,
  });

  final int pricePrecision;
  final int quantityPrecision;

  /// Smallest order in base units, already raised to satisfy the notional rule.
  final double minQuantity;

  /// Smallest order value in quote currency that the exchange accepts.
  final double minNotional;

  String formatPrice(double price) => price.toStringAsFixed(pricePrecision);

  String formatQuantity(double quantity) =>
      quantity.toStringAsFixed(quantityPrecision);
}

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;
