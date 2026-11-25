import 'package:flutter/foundation.dart';

import '../domain/api_keys.dart';
import '../domain/open_positions.dart';
import 'binance_api.dart';

/// Owns the account snapshot the dashboard renders.
///
/// Widgets listen instead of being handed raw maps; the home screen decides when
/// to refresh, so polling policy stays in the UI layer.
class PositionTracker {
  PositionTracker({required BinanceApi binance}) : _binance = binance;

  final BinanceApi _binance;
  final ValueNotifier<OpenPositions> _snapshot =
      ValueNotifier(OpenPositions.empty);

  ValueListenable<OpenPositions> get positions => _snapshot;

  OpenPositions get current => _snapshot.value;

  /// Reads positions, their conditional orders and the margin balance, then
  /// publishes one immutable snapshot.
  ///
  /// Without Binance keys there is nothing to read, so the previous snapshot is
  /// left untouched rather than replaced with an empty one.
  Future<OpenPositions> refresh(
    ApiKeys keys, {
    String quoteSymbol = 'USDT',
  }) async {
    if (!keys.hasBinance) return _snapshot.value;

    final positions = await _binance.getUserOpenPositions(keys);
    final orders = await Future.wait(
      positions
          .map((position) => _binance.getUserOpenOrders(keys, position.symbol)),
    );

    final balance = await _binance.getUserBalance(keys, quoteSymbol);

    final snapshots = <PositionSnapshot>[
      for (var i = 0; i < positions.length; i++)
        PositionSnapshot.from(position: positions[i], orders: orders[i]),
    ];

    _snapshot.value = OpenPositions(balance: balance, positions: snapshots);
    return _snapshot.value;
  }

  void dispose() => _snapshot.dispose();
}
