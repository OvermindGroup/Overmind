import '../domain/trade_settings.dart';
import 'local_store.dart';

/// Persistence for the per-trade allocation and leverage the dashboard edits.
class TradeSettingsStore {
  TradeSettingsStore({required LocalStore store}) : _store = store;

  static const String allocationKey = 'allocationUSDT';
  static const String leverageKey = 'leverage';

  final LocalStore _store;

  Future<TradeSettings> read() async {
    final allocation = await _store.read(allocationKey);
    final leverage = await _store.read(leverageKey);
    return TradeSettings(
      allocationUsdt: TradeSettings.parseAllocation(allocation),
      leverage: TradeSettings.parseLeverage(leverage),
    );
  }

  Future<void> write(TradeSettings settings) async {
    await _store.write(allocationKey, settings.allocationUsdt.toString());
    await _store.write(leverageKey, settings.leverage.toString());
  }
}
