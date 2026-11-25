import 'money.dart';

/// Margin account figures reported by Binance's `/fapi/v2/balance`.
class FuturesBalance {
  const FuturesBalance({
    this.totalBalance = 0,
    this.availableBalance = 0,
    this.unrealizedProfit = 0,
  });

  static const FuturesBalance empty = FuturesBalance();

  final double totalBalance;
  final double availableBalance;
  final double unrealizedProfit;

  /// Binance reports every balance field as a decimal string.
  factory FuturesBalance.fromApi(Map<String, dynamic> json) {
    return FuturesBalance(
      totalBalance: _asDouble(json['balance']),
      availableBalance: _asDouble(json['availableBalance']),
      unrealizedProfit: _asDouble(json['crossUnPnl']),
    );
  }

  bool canAfford(double amount) => availableBalance >= amount;

  String get totalFormatted => formatCurrency(totalBalance);
  String get availableFormatted => formatCurrency(availableBalance);
  String get profitFormatted => formatCurrency(unrealizedProfit);
}

double _asDouble(Object? value) =>
    double.tryParse(value?.toString() ?? '') ?? 0.0;
