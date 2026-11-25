/// Credentials the app needs to talk to Binance and to the Overmind server.
///
/// A value object so "are the keys set?" is decided in one place instead of
/// being re-spelled as `!= ''` all over the UI.
class ApiKeys {
  const ApiKeys({
    this.binanceApiKey = '',
    this.binanceApiSecret = '',
    this.overmindApiKey = '',
  });

  static const ApiKeys empty = ApiKeys();

  final String binanceApiKey;
  final String binanceApiSecret;
  final String overmindApiKey;

  /// Both halves are required: Binance signs requests with the secret.
  bool get hasBinance =>
      binanceApiKey.isNotEmpty && binanceApiSecret.isNotEmpty;

  bool get hasOvermind => overmindApiKey.isNotEmpty;

  bool get isComplete => hasBinance && hasOvermind;

  ApiKeys copyWith({
    String? binanceApiKey,
    String? binanceApiSecret,
    String? overmindApiKey,
  }) {
    return ApiKeys(
      binanceApiKey: binanceApiKey ?? this.binanceApiKey,
      binanceApiSecret: binanceApiSecret ?? this.binanceApiSecret,
      overmindApiKey: overmindApiKey ?? this.overmindApiKey,
    );
  }
}
