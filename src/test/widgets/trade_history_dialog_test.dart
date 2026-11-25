import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/trades.dart';
import 'package:overmind/widgets/trade_history_dialog.dart';

TradeFill _fill({
  required String orderId,
  double realizedPnl = 0,
  double commission = 0.5,
  required DateTime time,
}) {
  return TradeFill.fromApi({
    'orderId': orderId,
    'symbol': 'BTCUSDT',
    'side': 'BUY',
    'price': '100',
    'qty': '1',
    'realizedPnl': realizedPnl.toString(),
    'quoteQty': '100',
    'commission': commission.toString(),
    'commissionAsset': 'USDT',
    'time': time.millisecondsSinceEpoch,
  });
}

void main() {
  testWidgets('fetches the current month and totals the closed trades',
      (tester) async {
    DateTime? start;
    DateTime? end;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeHistoryDialog(
            fetchTrades: (from, to) async {
              start = from;
              end = to;
              final middle = from.add(Duration(
                  microseconds: to.difference(from).inMicroseconds ~/ 2));
              return [
                _fill(orderId: 'open', time: middle),
                _fill(
                    orderId: 'close',
                    realizedPnl: 8,
                    commission: 0.25,
                    time: middle.add(const Duration(minutes: 1))),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(start!.day, 1);
    expect(end!.isAfter(start!), isTrue);
    expect(find.text('User Trades Overview'), findsOneWidget);
    expect(find.textContaining('P&L: \$8.0000'), findsOneWidget);
    expect(find.textContaining('P&L (with commissions): \$7.2500'),
        findsOneWidget);
    expect(find.textContaining('Accuracy: 100.00% (1/1)'), findsOneWidget);
    expect(find.text('BTCUSDT'), findsOneWidget);
  });

  testWidgets('fills outside the window are excluded from the totals',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeHistoryDialog(
            fetchTrades: (from, to) async {
              final middle = from.add(Duration(
                  microseconds: to.difference(from).inMicroseconds ~/ 2));
              return [
                _fill(
                    orderId: 'old',
                    realizedPnl: 50,
                    time: from.subtract(const Duration(days: 1))),
                _fill(orderId: 'open', time: middle),
                _fill(
                    orderId: 'close',
                    realizedPnl: 6,
                    commission: 0.2,
                    time: middle.add(const Duration(minutes: 1))),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('P&L: \$6.0000'), findsOneWidget);
    expect(find.textContaining('(1/1)'), findsOneWidget);
  });

  testWidgets('a window with no trades reads as zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeHistoryDialog(
              fetchTrades: (from, to) async => const <TradeFill>[]),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('P&L: \$0.0000'), findsOneWidget);
    expect(find.textContaining('Accuracy: 0.00% (0/0)'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, isEmpty);
  });

  testWidgets('a failed fetch is reported in the dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeHistoryDialog(
            fetchTrades: (from, to) async =>
                throw Exception('Binance unavailable'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Error: Exception: Binance unavailable'),
        findsOneWidget);
  });
}
