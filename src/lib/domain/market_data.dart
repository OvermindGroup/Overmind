/// Market data read models: the order book snapshot and the indicator series
/// Overmind returns for the chart.
library;

/// Best bid/ask for a symbol from `/fapi/v1/ticker/bookTicker`.
class BookPrice {
  const BookPrice({required this.bid, required this.ask});

  final double bid;
  final double ask;

  factory BookPrice.fromApi(Map<String, dynamic> json) => BookPrice(
        bid: _asDouble(json['bidPrice']),
        ask: _asDouble(json['askPrice']),
      );
}

/// One candle of the Overmind "amherag" indicator series.
class AmheragCandle {
  const AmheragCandle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.above,
    required this.below,
    required this.max,
    required this.min,
  });

  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// Heights of the indicator cloud drawn above and below the candle.
  final List<double> above;
  final List<double> below;

  final double max;
  final double min;

  factory AmheragCandle.fromApi(Map<String, dynamic> json) {
    final candle = json['candle'];
    final raw =
        candle is Map<String, dynamic> ? candle : const <String, dynamic>{};
    return AmheragCandle(
      timestamp: _asInt(raw['date']),
      open: _asDouble(raw['open']),
      high: _asDouble(raw['high']),
      low: _asDouble(raw['low']),
      close: _asDouble(raw['close']),
      volume: _asDouble(raw['volume']),
      above: _asDoubles(json['above']),
      below: _asDoubles(json['below']),
      max: _asDouble(json['max']),
      min: _asDouble(json['min']),
    );
  }
}

/// The indicator series plus the scaling factor the painter applies to it.
class AmheragData {
  const AmheragData({required this.height, required this.candles});

  final double height;
  final List<AmheragCandle> candles;

  factory AmheragData.fromApi(Map<String, dynamic> json) => AmheragData(
        height: _asDouble(json['height']),
        candles: (json['candles'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AmheragCandle.fromApi)
            .toList(),
      );
}

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

List<double> _asDoubles(Object? value) => value is List
    ? value.whereType<num>().map((e) => e.toDouble()).toList()
    : const <double>[];
