import '../domain/api_keys.dart';
import 'local_store.dart';

/// Persistence for the exchange and Overmind keys.
class ApiKeyStore {
  ApiKeyStore({required LocalStore store}) : _store = store;

  static const String binanceApiKeyKey = 'binance_api_key';
  static const String binanceApiSecretKey = 'binance_api_secret';
  static const String overmindApiKeyKey = 'overmind_api_key';

  final LocalStore _store;

  Future<ApiKeys> read() async {
    final binanceApiKey = await _store.read(binanceApiKeyKey);
    final binanceApiSecret = await _store.read(binanceApiSecretKey);
    final overmindApiKey = await _store.read(overmindApiKeyKey);

    return ApiKeys(
      binanceApiKey: binanceApiKey ?? '',
      binanceApiSecret: binanceApiSecret ?? '',
      overmindApiKey: overmindApiKey ?? '',
    );
  }

  Future<void> write(ApiKeys keys) async {
    await _store.write(binanceApiKeyKey, keys.binanceApiKey);
    await _store.write(binanceApiSecretKey, keys.binanceApiSecret);
    await _store.write(overmindApiKeyKey, keys.overmindApiKey);
  }
}
