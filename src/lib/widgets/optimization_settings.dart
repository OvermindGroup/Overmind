import 'package:flutter/material.dart';

import 'modal_sheet.dart';

/// Filters the user chooses for portfolio optimisation.
///
/// Only [minTestingScore] is read by the app today: it decides which models are
/// "subpar" and therefore what Train/Reset Subpar Models acts on. The rest are
/// presented for the filters the server side has not wired up yet.
class OptimizationSettings {
  const OptimizationSettings({
    this.filterTopN = 0,
    this.selectedMarketType = 'noPreference',
    this.sandrPastN = 5,
    this.selectedMinTpSl = 0.0,
    this.minTpSlPadding = 0.0,
    this.minRiskReward = 0.0,
    this.maxRiskReward = 0.0,
    this.minTestingScore = 0.0,
    this.minOutputScore = 0.0,
    this.leverage = 1,
    this.filterOutHeldAssets = false,
    this.filterOutLostSymbols = false,
    this.showAffordable = false,
  });

  final int filterTopN;
  final String selectedMarketType;
  final int sandrPastN;
  final double selectedMinTpSl;
  final double minTpSlPadding;
  final double minRiskReward;
  final double maxRiskReward;
  final double minTestingScore;
  final double minOutputScore;
  final int leverage;
  final bool filterOutHeldAssets;
  final bool filterOutLostSymbols;
  final bool showAffordable;

  OptimizationSettings copyWith({
    int? filterTopN,
    String? selectedMarketType,
    int? sandrPastN,
    double? selectedMinTpSl,
    double? minTpSlPadding,
    double? minRiskReward,
    double? maxRiskReward,
    double? minTestingScore,
    double? minOutputScore,
    int? leverage,
    bool? filterOutHeldAssets,
    bool? filterOutLostSymbols,
    bool? showAffordable,
  }) {
    return OptimizationSettings(
      filterTopN: filterTopN ?? this.filterTopN,
      selectedMarketType: selectedMarketType ?? this.selectedMarketType,
      sandrPastN: sandrPastN ?? this.sandrPastN,
      selectedMinTpSl: selectedMinTpSl ?? this.selectedMinTpSl,
      minTpSlPadding: minTpSlPadding ?? this.minTpSlPadding,
      minRiskReward: minRiskReward ?? this.minRiskReward,
      maxRiskReward: maxRiskReward ?? this.maxRiskReward,
      minTestingScore: minTestingScore ?? this.minTestingScore,
      minOutputScore: minOutputScore ?? this.minOutputScore,
      leverage: leverage ?? this.leverage,
      filterOutHeldAssets: filterOutHeldAssets ?? this.filterOutHeldAssets,
      filterOutLostSymbols: filterOutLostSymbols ?? this.filterOutLostSymbols,
      showAffordable: showAffordable ?? this.showAffordable,
    );
  }
}

/// Sheet that edits [OptimizationSettings] and reports each change upward.
class OptimizationSettingsModal extends StatefulWidget {
  const OptimizationSettingsModal({
    required this.initialSettings,
    required this.onSettingsChanged,
    super.key,
  });

  final OptimizationSettings initialSettings;
  final ValueChanged<OptimizationSettings> onSettingsChanged;

  static const Map<String, String> _marketTypes = {
    'noPreference': 'No Preference',
    'trendingMarkets': 'Trending Markets',
    'stagnatedMarkets': 'Stagnated Markets',
  };

  static const List<int> _leverageChoices = [
    1,
    2,
    3,
    4,
    5,
    10,
    20,
    25,
    50,
    75,
    100,
    125,
  ];

  @override
  State<OptimizationSettingsModal> createState() =>
      _OptimizationSettingsModalState();
}

class _OptimizationSettingsModalState extends State<OptimizationSettingsModal> {
  late OptimizationSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _update(OptimizationSettings settings) {
    setState(() => _settings = settings);
    widget.onSettingsChanged(settings);
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<(T, String)> choices,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        DropdownButton<T>(
          value: value,
          dropdownColor: Colors.grey[800],
          items: [
            for (final (choice, text) in choices)
              DropdownMenuItem<T>(
                value: choice,
                child: Text(text, style: const TextStyle(color: Colors.white)),
              ),
          ],
          onChanged: (selected) => onChanged(selected as T),
        ),
      ],
    );
  }

  /// Settings expressed as a percentage, from 0 to `itemCount - 1` steps.
  Widget _percentage({
    required String label,
    required double value,
    int itemCount = 11,
    double step = 0.02,
    required ValueChanged<double> onChanged,
  }) {
    return _dropdown<double>(
      label: label,
      value: value,
      choices: [
        for (var index = 0; index < itemCount; index++)
          (index * step, '${(index * step * 100).toStringAsFixed(0)}%'),
      ],
      onChanged: onChanged,
    );
  }

  Widget _checkbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        Checkbox(
          value: value,
          onChanged: (selected) => onChanged(selected ?? false),
          activeColor: Colors.blue,
          checkColor: Colors.white,
        ),
      ],
    );
  }

  Widget _gap() => const SizedBox(height: 24);

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      title: 'Portfolio Optimization Settings',
      children: [
        _dropdown<int>(
          label: 'Top N Markets',
          value: _settings.filterTopN,
          choices: [
            for (var index = 0; index <= 20; index++)
              (index, index == 0 ? 'Use All' : '$index'),
          ],
          onChanged: (value) => _update(_settings.copyWith(filterTopN: value)),
        ),
        _gap(),
        _dropdown<String>(
          label: 'Market Type',
          value: _settings.selectedMarketType,
          choices: [
            for (final entry in OptimizationSettingsModal._marketTypes.entries)
              (entry.key, entry.value),
          ],
          onChanged: (value) =>
              _update(_settings.copyWith(selectedMarketType: value)),
        ),
        _gap(),
        _dropdown<int>(
          label: 'Past N Prices',
          value: _settings.sandrPastN,
          choices: [
            for (var index = 1; index <= 10; index++)
              (index * 5, '${index * 5}'),
          ],
          onChanged: (value) => _update(_settings.copyWith(sandrPastN: value)),
        ),
        _gap(),
        _percentage(
          label: 'Minimum TP&SL',
          value: _settings.selectedMinTpSl,
          onChanged: (value) =>
              _update(_settings.copyWith(selectedMinTpSl: value)),
        ),
        _gap(),
        _percentage(
          label: 'Minimum TP&SL Padding',
          value: _settings.minTpSlPadding,
          onChanged: (value) =>
              _update(_settings.copyWith(minTpSlPadding: value)),
        ),
        _gap(),
        _percentage(
          label: 'Minimum Risk/Reward',
          value: _settings.minRiskReward,
          itemCount: 21,
          step: 0.1,
          onChanged: (value) =>
              _update(_settings.copyWith(minRiskReward: value)),
        ),
        _gap(),
        _percentage(
          label: 'Maximum Risk/Reward',
          value: _settings.maxRiskReward,
          itemCount: 21,
          step: 0.1,
          onChanged: (value) =>
              _update(_settings.copyWith(maxRiskReward: value)),
        ),
        _gap(),
        _percentage(
          label: 'Minimum Testing Score',
          value: _settings.minTestingScore,
          onChanged: (value) =>
              _update(_settings.copyWith(minTestingScore: value)),
        ),
        _gap(),
        _percentage(
          label: 'Minimum Output Score',
          value: _settings.minOutputScore,
          onChanged: (value) =>
              _update(_settings.copyWith(minOutputScore: value)),
        ),
        _gap(),
        _dropdown<int>(
          label: 'Leverage',
          value: _settings.leverage,
          choices: [
            for (final value in OptimizationSettingsModal._leverageChoices)
              (value, '$value'),
          ],
          onChanged: (value) => _update(_settings.copyWith(leverage: value)),
        ),
        _gap(),
        _checkbox(
          label: 'Filter Out Held Assets',
          value: _settings.filterOutHeldAssets,
          onChanged: (value) =>
              _update(_settings.copyWith(filterOutHeldAssets: value)),
        ),
        _gap(),
        _checkbox(
          label: 'Filter Out Recently Lost Symbols',
          value: _settings.filterOutLostSymbols,
          onChanged: (value) =>
              _update(_settings.copyWith(filterOutLostSymbols: value)),
        ),
        _gap(),
        _checkbox(
          label: 'Show Affordable Only',
          value: _settings.showAffordable,
          onChanged: (value) =>
              _update(_settings.copyWith(showAffordable: value)),
        ),
      ],
    );
  }
}
