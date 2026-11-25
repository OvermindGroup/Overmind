import 'package:flutter/material.dart';

import '../services/overmind_api.dart';
import 'basic.dart';
import 'modal_sheet.dart';

/// Training parameters the user picks before asking the server to train.
class TrainingDraft {
  const TrainingDraft({
    this.iterations = 50,
    this.maxTradeHorizon = 288,
    this.takeProfitPercentage = 5,
    this.stopLossPercentage = 5,
  });

  final int iterations;
  final int maxTradeHorizon;

  /// Percentages, converted to fractions when the request is built.
  final double takeProfitPercentage;
  final double stopLossPercentage;

  TrainingDraft copyWith({
    int? iterations,
    int? maxTradeHorizon,
    double? takeProfitPercentage,
    double? stopLossPercentage,
  }) {
    return TrainingDraft(
      iterations: iterations ?? this.iterations,
      maxTradeHorizon: maxTradeHorizon ?? this.maxTradeHorizon,
      takeProfitPercentage: takeProfitPercentage ?? this.takeProfitPercentage,
      stopLossPercentage: stopLossPercentage ?? this.stopLossPercentage,
    );
  }

  TrainingRequest toRequest() => TrainingRequest(
        iterations: iterations,
        maxTradeHorizon: maxTradeHorizon,
        takeProfitPercentage: takeProfitPercentage / 100,
        stopLossPercentage: stopLossPercentage / 100,
      );
}

/// Collects training parameters and hands the request back to the screen.
class TrainingModal extends StatefulWidget {
  const TrainingModal({
    required this.onStartTraining,
    this.initial = const TrainingDraft(),
    super.key,
  });

  /// 'Train Full Portfolio' or 'Train Subpar Models' is decided by the screen,
  /// not by the sheet: the inputs are the same either way.
  static const String title = 'Training Settings';

  final Future<void> Function(TrainingRequest request) onStartTraining;
  final TrainingDraft initial;

  static const List<double> percentageChoices = [
    100,
    90,
    80,
    70,
    60,
    50,
    40,
    30,
    20,
    10
  ];

  @override
  State<TrainingModal> createState() => _TrainingModalState();
}

class _TrainingModalState extends State<TrainingModal> {
  late final TrainingDraft _draft;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await widget.onStartTraining(_draft.toRequest());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      title: TrainingModal.title,
      children: [
        sliderRow('Iterations', _draft.iterations, 100, (value) {
          setState(() => _draft = _draft.copyWith(iterations: value.toInt()));
        }),
        const SizedBox(height: 16),
        sliderRow('Max Trade Horizon (in hours)', _draft.maxTradeHorizon, 288,
            (value) {
          setState(
              () => _draft = _draft.copyWith(maxTradeHorizon: value.toInt()));
        }),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          children: [
            dropdownRow<double>(
              'Take Profit (%)',
              _draft.takeProfitPercentage,
              TrainingModal.percentageChoices,
              (value) => setState(() {
                _draft = _draft.copyWith(
                    takeProfitPercentage: value ?? _draft.takeProfitPercentage);
              }),
            ),
            dropdownRow<double>(
              'Stop Loss (%)',
              _draft.stopLossPercentage,
              TrainingModal.percentageChoices,
              (value) => setState(() {
                _draft = _draft.copyWith(
                    stopLossPercentage: value ?? _draft.stopLossPercentage);
              }),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy ? null : _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Text(_busy ? 'Training…' : 'Start Training'),
        ),
      ],
    );
  }
}
