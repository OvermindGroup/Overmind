import 'package:flutter/material.dart';

// optimization_settings_model.dart
class OptimizationSettings {
  int filterTopN;
  String selectedMarketType;
  int sandrPastN;
  double selectedMinTpSl;
  double minTpSlPadding;
  double minRiskReward;
  double maxRiskReward;
  double minTestingScore;
  double minOutputScore;
  int leverage;
  bool filterOutHeldAssets;
  bool filterOutLostSymbols;
  bool showAffordable;

  OptimizationSettings({
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

class OptimizationSettingsModal extends StatefulWidget {
  final OptimizationSettings initialSettings;
  final ValueChanged<OptimizationSettings> onSettingsChanged;

  const OptimizationSettingsModal({
      Key? key,
      required this.initialSettings,
      required this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<OptimizationSettingsModal> createState() => _OptimizationSettingsModalState();
}

class _OptimizationSettingsModalState extends State<OptimizationSettingsModal> {
  late OptimizationSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _updateSettings(OptimizationSettings newSettings) {
    setState(() {
        _settings = newSettings;
    });
    widget.onSettingsChanged(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthFactor = constraints.maxWidth > 600 ? 0.8 : 1.0;

        return FractionallySizedBox(
          widthFactor: widthFactor,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ModalTitle(),
                  const SizedBox(height: 24),
                  _buildSettingsContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      children: [
        _buildTopNMarketsDropdown(),
        const SizedBox(height: 24),
        _buildMarketTypeDropdown(),
        const SizedBox(height: 24),
        _buildPastNPricesDropdown(),
        const SizedBox(height: 24),
        _buildMinTpSlDropdown(),
        const SizedBox(height: 24),
        _buildMinTpSlPaddingDropdown(),
        const SizedBox(height: 24),
        _buildMinRiskRewardDropdown(),
        const SizedBox(height: 24),
        _buildMaxRiskRewardDropdown(),
        const SizedBox(height: 24),
        _buildMinTestingScoreDropdown(),
        const SizedBox(height: 24),
        _buildMinOutputScoreDropdown(),
        const SizedBox(height: 24),
        _buildLeverageDropdown(),
        const SizedBox(height: 24),
        _buildFilterOutHeldAssetsCheckbox(),
        const SizedBox(height: 24),
        _buildFilterOutLostSymbolsCheckbox(),
        const SizedBox(height: 24),
        _buildShowAffordableCheckbox(),
      ],
    );
  }

  Widget _buildTopNMarketsDropdown() {
    return _buildDropdownSetting<int>(
      label: 'Top N Markets',
      value: _settings.filterTopN,
      items: List.generate(21, (index) => _DropdownItem(
          value: index,
          label: index == 0 ? 'Use All' : '$index',
      )),
      onChanged: (value) => _updateSettings(_settings.copyWith(filterTopN: value)),
    );
  }

  Widget _buildMarketTypeDropdown() {
    const marketTypes = {
      'noPreference': 'No Preference',
      'trendingMarkets': 'Trending Markets',
      'stagnatedMarkets': 'Stagnated Markets',
    };

    return _buildDropdownSetting<String>(
      label: 'Market Type',
      value: _settings.selectedMarketType,
      items: marketTypes.entries.map((entry) => _DropdownItem(
          value: entry.key,
          label: entry.value,
      )).toList(),
      onChanged: (value) => _updateSettings(_settings.copyWith(selectedMarketType: value)),
    );
  }

  Widget _buildPastNPricesDropdown() {
    return _buildDropdownSetting<int>(
      label: 'Past N Prices',
      value: _settings.sandrPastN,
      items: List.generate(10, (index) => _DropdownItem(
          value: (index + 1) * 5,
          label: '${(index + 1) * 5}',
      )),
      onChanged: (value) => _updateSettings(_settings.copyWith(sandrPastN: value)),
    );
  }

  Widget _buildMinTpSlDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Minimum TP&SL',
      value: _settings.selectedMinTpSl,
      itemCount: 11,
      onChanged: (value) => _updateSettings(_settings.copyWith(selectedMinTpSl: value)),
    );
  }

  Widget _buildMinTpSlPaddingDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Minimum TP&SL Padding',
      value: _settings.minTpSlPadding,
      itemCount: 11,
      onChanged: (value) => _updateSettings(_settings.copyWith(minTpSlPadding: value)),
    );
  }

  Widget _buildMinRiskRewardDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Minimum Risk/Reward',
      value: _settings.minRiskReward,
      itemCount: 21,
      step: 0.1,
      onChanged: (value) => _updateSettings(_settings.copyWith(minRiskReward: value)),
    );
  }

  Widget _buildMaxRiskRewardDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Maximum Risk/Reward',
      value: _settings.maxRiskReward,
      itemCount: 21,
      step: 0.1,
      onChanged: (value) => _updateSettings(_settings.copyWith(maxRiskReward: value)),
    );
  }

  Widget _buildMinTestingScoreDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Minimum Testing Score',
      value: _settings.minTestingScore,
      itemCount: 11,
      onChanged: (value) => _updateSettings(_settings.copyWith(minTestingScore: value)),
    );
  }

  Widget _buildMinOutputScoreDropdown() {
    return _buildPercentageDropdownSetting(
      label: 'Minimum Output Score',
      value: _settings.minOutputScore,
      itemCount: 11,
      onChanged: (value) => _updateSettings(_settings.copyWith(minOutputScore: value)),
    );
  }

  Widget _buildLeverageDropdown() {
    final leverageValues = [1, 2, 3, 4, 5, 10, 20, 25, 50, 75, 100, 125];
    return _buildDropdownSetting<int>(
      label: 'Leverage',
      value: _settings.leverage,
      items: leverageValues.map((value) => _DropdownItem(
          value: value,
          label: '$value',
      )).toList(),
      onChanged: (value) => _updateSettings(_settings.copyWith(leverage: value)),
    );
  }

  Widget _buildFilterOutHeldAssetsCheckbox() {
    return _buildCheckboxSetting(
      label: 'Filter Out Held Assets',
      value: _settings.filterOutHeldAssets,
      onChanged: (value) => _updateSettings(_settings.copyWith(filterOutHeldAssets: value)),
    );
  }

  Widget _buildFilterOutLostSymbolsCheckbox() {
    return _buildCheckboxSetting(
      label: 'Filter Out Recently Lost Symbols',
      value: _settings.filterOutLostSymbols,
      onChanged: (value) => _updateSettings(_settings.copyWith(filterOutLostSymbols: value)),
    );
  }

  Widget _buildShowAffordableCheckbox() {
    return _buildCheckboxSetting(
      label: 'Show Affordable Only',
      value: _settings.showAffordable,
      onChanged: (value) => _updateSettings(_settings.copyWith(showAffordable: value)),
    );
  }
}

class _ModalTitle extends StatelessWidget {
  const _ModalTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Portfolio Optimization Settings',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _DropdownItem<T> {
  final T value;
  final String label;

  const _DropdownItem({required this.value, required this.label});
}

Widget _buildDropdownSetting<T>({
    required String label,
    required T value,
    required List<_DropdownItem<T>> items,
    required ValueChanged<T> onChanged,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      DropdownButton<T>(
        value: value,
        dropdownColor: Colors.grey[800],
        items: items.map((item) => DropdownMenuItem(
            value: item.value,
            child: Text(
              item.label,
              style: const TextStyle(color: Colors.white),
            ),
        )).toList(),
        onChanged: (value) => onChanged(value as T),
      ),
    ],
  );
}

Widget _buildPercentageDropdownSetting({
    required String label,
    required double value,
    required int itemCount,
    double step = 0.02,
    required ValueChanged<double> onChanged,
}) {
  return _buildDropdownSetting<double>(
    label: label,
    value: value,
    items: List.generate(itemCount, (index) {
        final percentage = index * step;
        return _DropdownItem(
          value: percentage,
          label: '${(percentage * 100).toStringAsFixed(0)}%',
        );
    }),
    onChanged: onChanged,
  );
}

Widget _buildCheckboxSetting({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      Checkbox(
        value: value,
        onChanged: (value) => onChanged(value ?? false),
        activeColor: Colors.blue,
        checkColor: Colors.white,
      ),
    ],
  );
}
