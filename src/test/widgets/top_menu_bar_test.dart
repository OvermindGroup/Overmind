import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/widgets/top_menu_bar.dart';

Widget _menu({
  String selectedSymbol = 'BTCUSDT',
  bool isAutoTrade = false,
  ValueChanged<String>? onSymbolSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TopMenuBar(
        onOptimizedPortfolio: () {},
        onTradeHistory: () {},
        onOptimizationSettings: () {},
        onTrainPortfolio: () {},
        onTrainSubparModels: () {},
        onResetPortfolio: () {},
        onResetSubparModels: () {},
        onApiKeys: () {},
        onToggleAutoTrade: () {},
        onSymbolSelected: onSymbolSelected ?? (_) {},
        symbols: const ['BTCUSDT', 'ETHUSDT'],
        selectedSymbol: selectedSymbol,
        isAutoTrade: isAutoTrade,
      ),
    ),
  );
}

/// PlutoMenuBar puts entries into an overflow menu when the window is narrow,
/// so the dashboard's landscape width is used here.
Future<void> _pumpMenu(WidgetTester tester, Widget menu) async {
  await tester.binding.setSurfaceSize(const Size(2200, 1200));
  await tester.pumpWidget(menu);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the menu entries and the selected symbol', (tester) async {
    await _pumpMenu(tester, _menu());

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Optimization Settings'), findsOneWidget);
    expect(find.text('API Keys'), findsOneWidget);
    expect(find.text('Go PRO'), findsOneWidget);
    expect(find.text('Report Issue'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'BTCUSDT',
    );
  });

  testWidgets('choosing a symbol reports it upward', (tester) async {
    var selected = '';

    await _pumpMenu(
        tester, _menu(onSymbolSelected: (symbol) => selected = symbol));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETHUSDT').last);
    await tester.pump();

    expect(selected, 'ETHUSDT');
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'ETHUSDT',
    );
  });

  testWidgets('the dropdown follows a symbol the screen selected itself',
      (tester) async {
    await _pumpMenu(tester, _menu());
    await _pumpMenu(tester, _menu(selectedSymbol: 'ETHUSDT'));

    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'ETHUSDT',
    );
  });

  testWidgets('toggling auto trading keeps the menu usable', (tester) async {
    await _pumpMenu(tester, _menu());
    await _pumpMenu(tester, _menu(isAutoTrade: true));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('API Keys'), findsOneWidget);
  });
}
