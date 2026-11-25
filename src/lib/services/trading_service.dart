import 'package:collection/collection.dart' show IterableExtension;

import '../domain/action_result.dart';
import '../domain/api_keys.dart';
import '../domain/portfolio.dart';
import '../domain/trade_settings.dart';
import '../utils/log.dart';
import 'binance_api.dart';
import 'overmind_api.dart';
import 'position_tracker.dart';

/// Turns model signals into Binance futures orders.
///
/// Every method reports an [ActionResult] instead of throwing: a rejected order
/// is a normal outcome for a trading loop and for a button press, so callers
/// show the message rather than unwinding.
class TradingService {
  TradingService({
    required BinanceApi binance,
    required OvermindApi overmind,
    required PositionTracker positions,
    this.quoteSymbol = 'USDT',
  })  : _binance = binance,
        _overmind = overmind,
        _positions = positions;

  /// Margin currency every balance check is denominated in.
  final String quoteSymbol;

  final BinanceApi _binance;
  final OvermindApi _overmind;
  final PositionTracker _positions;

  /// Opens a position for [holding], sizing it by the signal's trade factor.
  ///
  /// Conditional orders are placed before the market order so a fill always has
  /// a take-profit and a stop-loss resting against it.
  Future<ActionResult> openPosition(
    ApiKeys keys,
    Holding holding,
    double allocationUsdt,
    int leverage,
  ) async {
    final symbol = holding.instrument;

    try {
      final factor = holding.calculateTradeFactor();
      if (factor <= 0) {
        return ActionResult.failure(
          '$symbol: output score ${holding.outputScore.toStringAsFixed(2)} is too weak to trade',
        );
      }
      if (allocationUsdt <= 0) {
        return ActionResult.failure(
            '$symbol: set an allocation per trade first');
      }

      final price = await _overmind.getLatestPrice(keys.overmindApiKey, symbol);
      if (price <= 0) {
        return ActionResult.failure('$symbol: no market price available');
      }

      final precision =
          (await _binance.futuresMinimumQuantities([symbol]))[symbol];
      if (precision == null) {
        return ActionResult.failure('$symbol: exchange info unavailable');
      }

      final allocation = allocationUsdt * factor;
      final balance = await _binance.getUserBalance(keys, quoteSymbol);
      if (!balance.canAfford(allocation)) {
        return ActionResult.failure(
          '\$${allocation.toStringAsFixed(2)} needed for $symbol, only \$${balance.availableBalance.toStringAsFixed(2)} available',
        );
      }

      final quantity = allocation / price;
      if (quantity < precision.minQuantity) {
        return ActionResult.failure(
          '$symbol: \$${allocation.toStringAsFixed(2)} buys ${quantity.toStringAsFixed(6)}, '
          'below the exchange minimum of ${precision.minQuantity}',
        );
      }

      final formattedQuantity = precision.formatQuantity(quantity);
      final formattedTakeProfit =
          precision.formatPrice(price + holding.takeProfit);
      final formattedStopLoss = precision.formatPrice(price + holding.stopLoss);

      final entrySide = holding.isLong ? 'BUY' : 'SELL';
      final closingSide = holding.isLong ? 'SELL' : 'BUY';

      await _binance.changeLeverage(keys, symbol, leverage);

      final cleared = await _binance.cancelAllOrders(keys, symbol);
      if (!cleared.accepted) {
        return ActionResult.failure('$symbol: ${cleared.message}');
      }

      final takeProfit = await _binance.createTakeProfitOrder(
        keys,
        symbol,
        closingSide,
        formattedQuantity,
        formattedTakeProfit,
      );
      if (!takeProfit.accepted) {
        return ActionResult.failure(
          '$symbol: take profit order rejected (${takeProfit.status})',
        );
      }

      final stopLoss = await _binance.createStopLossOrder(
        keys,
        symbol,
        closingSide,
        formattedQuantity,
        formattedStopLoss,
      );
      if (!stopLoss.accepted) {
        return ActionResult.failure(
            '$symbol: stop loss order rejected (${stopLoss.status})');
      }

      final entry = await _binance.createFuturesMarketOrder(
        keys,
        symbol,
        entrySide,
        formattedQuantity,
      );
      if (!entry.accepted) {
        return ActionResult.failure(
          '$symbol: market order rejected (${entry.message.isNotEmpty ? entry.message : entry.status})',
        );
      }

      await _positions.refresh(keys, quoteSymbol: quoteSymbol);
      return ActionResult('$symbol: position opened');
    } catch (error) {
      logError('opening a position for $symbol', error);
      return ActionResult.failure('$symbol: ${error.toString()}');
    }
  }

  /// Trades every signal in [portfolio] that is not already held.
  Future<List<ActionResult>> executePortfolio(
    ApiKeys keys,
    Portfolio portfolio,
    TradeSettings settings,
  ) async {
    final outcomes = <ActionResult>[];
    for (final holding in portfolio.holdings) {
      final resting = await _binance.getUserOpenPositionsBySymbol(
        keys,
        holding.instrument,
      );
      if (resting.isEmpty) {
        outcomes.add(
          await openPosition(
            keys,
            holding,
            settings.allocationUsdt,
            settings.leverage,
          ),
        );
      }
    }

    for (final outcome in outcomes.where((outcome) => !outcome.success)) {
      log(outcome.message);
    }
    return outcomes;
  }

  /// Re-points the resting take-profit to the level the model now recommends.
  Future<ActionResult> updateTakeProfit(
          ApiKeys keys, String symbol, Holding holding) =>
      _replaceOrder(keys, symbol, 'TAKE_PROFIT_MARKET', holding.takeProfit);

  Future<ActionResult> updateStopLoss(
          ApiKeys keys, String symbol, Holding holding) =>
      _replaceOrder(keys, symbol, 'STOP_MARKET', holding.stopLoss);

  /// Re-points both orders, or closes the position when the recommended levels
  /// no longer describe what is being held.
  Future<ActionResult> updateBoth(
      ApiKeys keys, String symbol, Holding holding) async {
    try {
      final position =
          (await _binance.getUserOpenPositionsBySymbol(keys, symbol))
              .firstOrNull;
      if (position == null) {
        return ActionResult.failure('$symbol: no open position to update');
      }

      final price = await _overmind.getLatestPrice(keys.overmindApiKey, symbol);
      final precision =
          (await _binance.futuresMinimumQuantities([symbol]))[symbol];
      if (precision == null) {
        return ActionResult.failure('$symbol: exchange info unavailable');
      }

      final quantity = position.positionAmount.abs().toString();
      final closingSide = position.positionAmount > 0 ? 'SELL' : 'BUY';
      final takeProfitPrice = price + holding.takeProfit;
      final stopLossPrice = price + holding.stopLoss;

      // Both levels sitting on the same side of the market price, or levels that
      // contradict the held direction, mean the signal no longer matches the
      // position: close it rather than rest orders that cannot fill.
      final shouldClose = (holding.takeProfit >= holding.stopLoss &&
              closingSide == 'BUY') ||
          (holding.takeProfit <= holding.stopLoss && closingSide == 'SELL') ||
          (takeProfitPrice >= price && stopLossPrice >= price) ||
          (takeProfitPrice <= price && stopLossPrice <= price);

      final cleared = await _binance.cancelAllOrders(keys, symbol);
      if (!cleared.accepted) {
        return ActionResult.failure('$symbol: ${cleared.message}');
      }

      if (shouldClose) {
        final closed = await _binance.createFuturesMarketOrder(
          keys,
          symbol,
          closingSide,
          quantity,
        );
        await _positions.refresh(keys, quoteSymbol: quoteSymbol);
        return closed.accepted
            ? ActionResult('$symbol position and stop orders closed')
            : ActionResult.failure('$symbol: closing order rejected');
      }

      final takeProfit = await _binance.createTakeProfitOrder(
        keys,
        symbol,
        closingSide,
        quantity,
        precision.formatPrice(takeProfitPrice),
      );
      final stopLoss = await _binance.createStopLossOrder(
        keys,
        symbol,
        closingSide,
        quantity,
        precision.formatPrice(stopLossPrice),
      );

      await _positions.refresh(keys, quoteSymbol: quoteSymbol);
      return takeProfit.accepted && stopLoss.accepted
          ? ActionResult('$symbol take profit and stop loss updated')
          : ActionResult.failure('$symbol: stop orders rejected');
    } catch (error) {
      logError('updating orders for $symbol', error);
      return ActionResult.failure('$symbol: ${error.toString()}');
    }
  }

  Future<ActionResult> closePosition(ApiKeys keys, String symbol) async {
    try {
      final position =
          (await _binance.getUserOpenPositionsBySymbol(keys, symbol))
              .firstOrNull;
      if (position == null) {
        return ActionResult.failure('$symbol: no open position to close');
      }

      final quantity = position.positionAmount.abs().toString();
      final closingSide = position.positionAmount > 0 ? 'SELL' : 'BUY';

      final cleared = await _binance.cancelAllOrders(keys, symbol);
      if (!cleared.accepted) {
        return ActionResult.failure('$symbol: ${cleared.message}');
      }

      final closed = await _binance.createFuturesMarketOrder(
        keys,
        symbol,
        closingSide,
        quantity,
      );
      await _positions.refresh(keys, quoteSymbol: quoteSymbol);
      return closed.accepted
          ? ActionResult('$symbol position and orders closed')
          : ActionResult.failure('$symbol: closing order rejected');
    } catch (error) {
      logError('closing $symbol', error);
      return ActionResult.failure('$symbol: ${error.toString()}');
    }
  }

  /// Cancels one resting conditional order and rests a new one at the level the
  /// model recommends, keeping the side and quantity of the order being replaced.
  Future<ActionResult> _replaceOrder(
    ApiKeys keys,
    String symbol,
    String orderType,
    double offset,
  ) async {
    final label =
        orderType == 'TAKE_PROFIT_MARKET' ? 'take profit' : 'stop loss';

    try {
      final orders = await _binance.getUserOpenOrders(keys, symbol);
      final order = orders.where((o) => o.type == orderType).firstOrNull;
      if (order == null) {
        return ActionResult.failure('$symbol: no $label order to update');
      }

      final price = await _overmind.getLatestPrice(keys.overmindApiKey, symbol);
      final precision =
          (await _binance.futuresMinimumQuantities([symbol]))[symbol];
      if (precision == null) {
        return ActionResult.failure('$symbol: exchange info unavailable');
      }

      final canceled = await _binance.cancelOrder(keys, order.orderId, symbol);
      if (!canceled.accepted) {
        return ActionResult.failure(
          '$symbol: could not cancel the $label order (${canceled.message})',
        );
      }

      final triggerPrice = precision.formatPrice(price + offset);
      final created = orderType == 'TAKE_PROFIT_MARKET'
          ? await _binance.createTakeProfitOrder(
              keys,
              symbol,
              order.side,
              order.quantity,
              triggerPrice,
            )
          : await _binance.createStopLossOrder(
              keys,
              symbol,
              order.side,
              order.quantity,
              triggerPrice,
            );

      await _positions.refresh(keys, quoteSymbol: quoteSymbol);
      return created.accepted
          ? ActionResult('$symbol $label order updated')
          : ActionResult.failure(
              '$symbol: $label order rejected (${created.status})');
    } catch (error) {
      logError('updating the $label order for $symbol', error);
      return ActionResult.failure('$symbol: $label update failed');
    }
  }
}
