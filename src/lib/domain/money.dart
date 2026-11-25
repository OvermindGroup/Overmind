/// USD figure formatted with the number of decimals the value needs.
///
/// Shared by the P&L chart axis, the position table and the trade history so
/// they all round the same way.
String formatCurrency(num value) {
  final magnitude = value.abs();
  final decimals = magnitude >= 100
      ? 0
      : magnitude >= 10
          ? 1
          : magnitude >= 1
              ? 2
              : magnitude >= 0.1
                  ? 3
                  : magnitude >= 0.01
                      ? 4
                      : magnitude >= 0.001
                          ? 5
                          : 6;
  return '\$${value.toStringAsFixed(decimals)}';
}
