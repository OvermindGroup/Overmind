import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/api_keys.dart';
import 'package:overmind/widgets/api_keys_modal.dart';
import 'package:overmind/widgets/modal_sheet.dart';

/// Opens [child] the way the dashboard does: as a modal bottom sheet, so the
/// sheet's own pop is safe to exercise.
Future<void> _openSheet(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSheet(context, child),
            child: const Text('open sheet'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
}

/// Scrolls the sheet to the control and presses it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('asks for the keys that are missing', (tester) async {
    await _openSheet(
      tester,
      ApiKeysModal(
        keys: const ApiKeys(binanceApiKey: 'key', binanceApiSecret: 'secret'),
        onRequestFreeTierKey: () async => 'free',
        onSave: (_) async {},
      ),
    );

    expect(find.text('API Keys'), findsOneWidget);
    expect(find.text('Please provide your Binance API key and secret'),
        findsNothing);
    expect(
        find.text('Please provide your Overmind PRO API key'), findsOneWidget);
    expect(find.text('Get Free-Tier Key'), findsOneWidget);
  });

  testWidgets('a free-tier key lands in the Overmind field', (tester) async {
    await _openSheet(
      tester,
      ApiKeysModal(
        keys: ApiKeys.empty,
        onRequestFreeTierKey: () async => 'free-tier-key',
        onSave: (_) async {},
      ),
    );

    await _tap(tester, find.text('Get Free-Tier Key'));

    final field = find.widgetWithText(TextField, 'Overmind API Key');
    expect(tester.widget<TextField>(field).controller?.text, 'free-tier-key');
    expect(find.text('Please provide your Overmind PRO API key'), findsNothing);
  });

  testWidgets('storing saves exactly what was typed, trimmed', (tester) async {
    final stored = <ApiKeys>[];

    await _openSheet(
      tester,
      ApiKeysModal(
        keys: const ApiKeys(
          binanceApiKey: 'old',
          binanceApiSecret: 'old-secret',
          overmindApiKey: 'old-key',
        ),
        onRequestFreeTierKey: () async => 'free',
        onSave: (keys) async {
          stored.add(keys);
        },
      ),
    );

    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Binance API Key'))
            .controller
            ?.text,
        'old');

    await tester.enterText(
        find.widgetWithText(TextField, 'Binance API Key'), ' new-key ');
    await tester.enterText(
        find.widgetWithText(TextField, 'Binance API Secret'), 'new-secret');
    await tester.enterText(
        find.widgetWithText(TextField, 'Overmind API Key'), 'new-key');

    final store = find.text('Store Securely');
    await tester.ensureVisible(store);
    await tester.tap(store);
    await tester.pumpAndSettle();

    expect(stored.single.binanceApiKey, 'new-key');
    expect(stored.single.binanceApiSecret, 'new-secret');
    expect(stored.single.overmindApiKey, 'new-key');
  });

  testWidgets('the sheet closes once the keys are stored', (tester) async {
    await _openSheet(
      tester,
      ApiKeysModal(
        keys: ApiKeys.empty,
        onRequestFreeTierKey: () async => 'free',
        onSave: (_) async {},
      ),
    );

    final store = find.text('Store Securely');
    await tester.ensureVisible(store);
    await tester.tap(store);
    await tester.pumpAndSettle();

    expect(find.text('API Keys'), findsNothing);
  });

  testWidgets('a failed free-tier request is shown to the user',
      (tester) async {
    await _openSheet(
      tester,
      ApiKeysModal(
        keys: ApiKeys.empty,
        onRequestFreeTierKey: () async => throw Exception('rate limited'),
        onSave: (_) async {},
      ),
    );

    await _tap(tester, find.text('Get Free-Tier Key'));

    expect(find.textContaining('Failed to get free-tier key'), findsOneWidget);
    expect(find.text('Get Free-Tier Key'), findsOneWidget);
  });
}
