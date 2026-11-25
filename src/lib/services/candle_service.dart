import 'package:interactive_chart/interactive_chart.dart';

import '../domain/api_keys.dart';
import 'binance_api.dart';
import 'overmind_api.dart';

/// Candles plus the indicator height the chart scales by, ready to render.
class CandleSeries {
  const CandleSeries({
    required this.candles,
    required this.amheragHeight,
    required this.lastClose,
  });

  static const CandleSeries empty = CandleSeries(
    candles: [],
    amheragHeight: 0,
    lastClose: 0,
  );

  final List<CandleData> candles;
  final double amheragHeight;

  /// Close of the newest candle as the model server reported it.
  final double lastClose;

  bool get isEmpty => candles.isEmpty;
}

/// Builds the chart series for one symbol.
///
/// The newest candle is priced off the live order book instead of the server's
/// close, because the server's last candle is not real time. A short signal is
/// priced off the bid and a long one off the ask, which is the price the trade
/// would actually have taken.
class CandleService {
  CandleService({
    required OvermindApi overmind,
    required BinanceApi binance,
  })  : _overmind = overmind,
        _binance = binance;

  final OvermindApi _overmind;
  final BinanceApi _binance;

  Future<CandleSeries> load({
    required String symbol,
    required String timeframe,
    required ApiKeys keys,
    required bool preferBid,
  }) async {
    final amherag =
        await _overmind.getAmherag(keys.overmindApiKey, symbol, timeframe);
    final book = await _binance.getBookPrices([symbol]);

    final livePrice =
        preferBid ? (book[symbol]?.bid ?? 0) : (book[symbol]?.ask ?? 0);

    final candles = <CandleData>[];
    for (var i = 0; i < amherag.candles.length; i++) {
      final candle = amherag.candles[i];
      final isLive = i == amherag.candles.length - 1;
      candles.add(
        CandleData(
          timestamp: candle.timestamp,
          open: candle.open,
          high: candle.high,
          low: candle.low,
          close: isLive ? livePrice : candle.close,
          volume: candle.volume,
          amheragAbove: candle.above,
          amheragBelow: candle.below,
          amheragMax: candle.max,
          amheragMin: candle.min,
        ),
      );
    }

    return CandleSeries(
      candles: candles,
      amheragHeight: amherag.height,
      lastClose: amherag.candles.isEmpty ? 0 : amherag.candles.last.close,
    );
  }
}
