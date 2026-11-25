/// How much capital a single trade uses, and the leverage to request for it.
class TradeSettings {
  const TradeSettings({this.allocationUsdt = 0, this.leverage = 1});

  static const TradeSettings defaults = TradeSettings();

  final double allocationUsdt;
  final int leverage;

  /// Binance rejects leverage below 1, so a malformed stored value falls back
  /// to the safest setting instead of asking for 0x.
  static int parseLeverage(String? stored) => int.tryParse(stored ?? '') ?? 1;

  static double parseAllocation(String? stored) =>
      double.tryParse(stored ?? '') ?? 0;
}
