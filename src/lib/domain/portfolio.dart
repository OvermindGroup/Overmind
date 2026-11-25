/// A closed trade the model reported, rendered as a bar in the holdings table.
class ModelTrade {
  const ModelTrade({required this.revenue, required this.direction});

  final double revenue;

  /// Positive when the model traded in the same direction as the signal.
  final double direction;

  /// Returns null for malformed entries so a bad payload degrades to "no
  /// trades" rather than throwing inside the table builder.
  static ModelTrade? tryFrom(Object? json) {
    if (json is List && json.length == 2 && json[0] is num && json[1] is num) {
      return ModelTrade(
          revenue: json[0].toDouble(), direction: json[1].toDouble());
    }
    return null;
  }
}

/// A trained signal for one instrument on one timeframe.
class Holding {
  const Holding({
    required this.instrument,
    required this.timeframe,
    required this.takeProfit,
    required this.stopLoss,
    required this.riskReward,
    required this.horizon,
    required this.horizonFormatted,
    required this.allocation,
    required this.testingScore,
    required this.trainingScore,
    required this.outputScore,
    required this.outputDelta,
    required this.outputActivation,
    required this.tpVolPerc,
    required this.slVolPerc,
    required this.direction1,
    required this.direction2,
    required this.tpLower,
    required this.tpUpper,
    this.lastTrades = const [],
  });

  /// Placeholder used when the portfolio has no signal for an instrument, so
  /// callers can keep asking for TP/SL distances without null checks.
  static Holding noSignal(String instrument, String timeframe) {
    return Holding(
      instrument: instrument,
      timeframe: timeframe,
      takeProfit: 0,
      stopLoss: 0,
      riskReward: 0,
      horizon: 0,
      horizonFormatted: '',
      allocation: 0,
      testingScore: 0,
      trainingScore: 0,
      outputScore: 0,
      outputDelta: 0,
      outputActivation: 0,
      tpVolPerc: 0,
      slVolPerc: 0,
      direction1: 0,
      direction2: 0,
      tpLower: 0,
      tpUpper: 0,
    );
  }

  final String instrument;
  final String timeframe;

  /// Absolute price offsets from the current market price: takeProfit is
  /// positive for a long, negative for a short.
  final double takeProfit;
  final double stopLoss;

  final double riskReward;
  final int horizon;
  final String horizonFormatted;
  final double allocation;

  final double testingScore;
  final double trainingScore;
  final double outputScore;
  final double outputDelta;
  final double outputActivation;

  final double tpVolPerc;
  final double slVolPerc;
  final double direction1;
  final double direction2;

  /// Bounds the model expects the take-profit offset to sit inside.
  final double tpLower;
  final double tpUpper;

  final List<ModelTrade> lastTrades;

  bool get isLong => takeProfit > 0;

  /// Fraction of the allocation to use, ramping from 0 at a 0.6 output score
  /// to 1 at 0.8. Below 0.6 the signal is not worth trading at all.
  double calculateTradeFactor() {
    if (outputScore < 0.6) return 0;
    if (outputScore >= 0.8) return 1;
    return 0.5 + (outputScore - 0.6) / 0.2 * 0.5;
  }

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      instrument: _asString(json['instrument']),
      timeframe: _asString(json['timeframe']),
      takeProfit: _asDouble(json['takeProfit']),
      stopLoss: _asDouble(json['stopLoss']),
      riskReward: _asDouble(json['riskReward']),
      horizon: _asInt(json['horizon']),
      horizonFormatted: _asString(json['horizonFormatted']),
      allocation: _asDouble(json['allocation']),
      testingScore: _asDouble(json['testingScore']),
      trainingScore: _asDouble(json['trainingScore']),
      outputScore: _asDouble(json['outputScore']),
      outputDelta: _asDouble(json['outputDelta']),
      outputActivation: _asDouble(json['outputActivation']),
      tpVolPerc: _asDouble(json['tpVolPerc']),
      slVolPerc: _asDouble(json['slVolPerc']),
      direction1: _asDouble(json['direction1']),
      direction2: _asDouble(json['direction2']),
      tpLower: _asDouble(json['tpLower']),
      tpUpper: _asDouble(json['tpUpper']),
      lastTrades: _asList(json['lastTrades'])
          .map(ModelTrade.tryFrom)
          .whereType<ModelTrade>()
          .toList(),
    );
  }
}

/// The full set of trained signals for a user.
///
/// Instances are immutable: filtering returns a new portfolio, which keeps a
/// "full" portfolio from being silently narrowed by a filtered copy that
/// shared its list.
class Portfolio {
  Portfolio({required List<Holding> holdings})
      : holdings = List.unmodifiable(holdings);

  factory Portfolio.fromJson(List<dynamic> json) {
    return Portfolio(
      holdings:
          json.whereType<Map<String, dynamic>>().map(Holding.fromJson).toList(),
    );
  }

  static final Portfolio empty = Portfolio(holdings: const []);

  final List<Holding> holdings;

  /// Instruments with their first occurrence order preserved; the same
  /// instrument appears once per trained timeframe.
  List<String> get symbols =>
      holdings.map((h) => h.instrument).toSet().toList();

  int get length => holdings.length;

  bool get isEmpty => holdings.isEmpty;

  List<T> map<T>(T Function(Holding) transform) =>
      holdings.map(transform).toList();

  Portfolio where(bool Function(Holding) test) =>
      Portfolio(holdings: holdings.where(test).toList());

  /// The holding trained for [instrument] on [timeframe], null when there is none.
  Holding? holdingFor(String instrument, String timeframe) {
    for (final holding in holdings) {
      if (holding.instrument == instrument && holding.timeframe == timeframe) {
        return holding;
      }
    }
    return null;
  }

  /// Signals worth trading: a usable take-profit band, a passing output score
  /// and directions that agree with the trade side.
  Portfolio filteredBest() {
    const dirThreshold = 0.50;
    const minOutputScore = 0.60;
    return Portfolio(
      holdings: holdings.where((holding) {
        if (holding.tpLower <= 0 || holding.tpUpper <= 0) return false;
        final scoreOk = holding.outputScore >= minOutputScore;
        final directionOk = (holding.takeProfit > 0 &&
                holding.direction1 > dirThreshold &&
                holding.direction2 < -dirThreshold) ||
            (holding.takeProfit < 0 &&
                holding.direction1 < -dirThreshold &&
                holding.direction2 > dirThreshold);
        return scoreOk && directionOk;
      }).toList(),
    );
  }

  /// Holdings whose testing score is below [minTestingScore].
  Portfolio subpar(double minTestingScore) =>
      where((holding) => holding.testingScore < minTestingScore);
}

String _asString(Object? value) => value?.toString() ?? '';

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0.0;

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

List<dynamic> _asList(Object? value) => value is List ? value : const [];
