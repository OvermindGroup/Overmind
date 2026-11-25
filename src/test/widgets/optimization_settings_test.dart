import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/widgets/modal_sheet.dart';
import 'package:overmind/widgets/optimization_settings.dart';

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

void main() {
  testWidgets('shows the settings it was given', (tester) async {
    await _openSheet(
      tester,
      OptimizationSettingsModal(
        initialSettings:
            const OptimizationSettings(minTestingScore: 0.12, filterTopN: 5),
        onSettingsChanged: (_) {},
      ),
    );

    expect(find.text('Portfolio Optimization Settings'), findsOneWidget);
    expect(find.text('Top N Markets'), findsOneWidget);
    expect(find.text('Minimum Testing Score'), findsOneWidget);
    // The testing score is offered in 2% steps, so 0.12 reads as 12%.
    expect(find.text('12%'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).first)
          .value,
      5,
    );
  });

  testWidgets('changing the last checkbox keeps every other setting',
      (tester) async {
    final changes = <OptimizationSettings>[];

    await _openSheet(
      tester,
      OptimizationSettingsModal(
        initialSettings:
            const OptimizationSettings(minTestingScore: 0.12, filterTopN: 5),
        onSettingsChanged: changes.add,
      ),
    );

    final lastCheckbox = find.byType(Checkbox).last;
    await tester.ensureVisible(lastCheckbox);
    await tester.tap(lastCheckbox);
    await tester.pump();

    expect(changes.single.showAffordable, isTrue);
    expect(changes.single.minTestingScore, closeTo(0.12, 0.0001));
    expect(changes.single.filterTopN, 5);
  });

  testWidgets('choosing Top N keeps every other setting', (tester) async {
    final changes = <OptimizationSettings>[];

    await _openSheet(
      tester,
      OptimizationSettingsModal(
        initialSettings:
            const OptimizationSettings(minTestingScore: 0.12, filterTopN: 5),
        onSettingsChanged: changes.add,
      ),
    );

    final topN = find.byType(DropdownButton<int>).first;
    await tester.ensureVisible(topN);
    await tester.tap(topN);
    await tester.pumpAndSettle();

    await tester.tap(find.text('10'));
    await tester.pump();

    expect(changes.single.filterTopN, 10);
    expect(changes.single.minTestingScore, closeTo(0.12, 0.0001));
  });
}
