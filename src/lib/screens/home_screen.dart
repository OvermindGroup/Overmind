import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';

import '../app.dart';
import '../domain/action_result.dart';
import '../domain/api_keys.dart';
import '../domain/chart_state.dart';
import '../domain/portfolio.dart';
import '../domain/trade_settings.dart';
import '../services/api_key_store.dart';
import '../services/binance_api.dart';
import '../services/candle_service.dart';
import '../services/local_store.dart';
import '../services/overmind_api.dart';
import '../services/periodic_task.dart';
import '../services/position_tracker.dart';
import '../services/sound_cue.dart';
import '../services/trade_settings_store.dart';
import '../services/trading_service.dart';
import '../services/update_checker.dart';
import '../utils/log.dart';
import '../widgets/api_keys_modal.dart';
import '../widgets/feedback.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/optimization_settings.dart';
import '../widgets/portfolio_panel.dart';
import '../widgets/top_menu_bar.dart';
import '../widgets/trade_history_dialog.dart';
import '../widgets/training_modal.dart';

/// The chart screen: candles, the portfolio drawer and the refresh policy that
/// keeps both current.
///
/// Services do the work; this class owns state, timers and the UI glue.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultSymbol = 'BTCUSDT';
  static const String _timeframe = '5m';
  static const String _auxTimeframe = '30m';
  static const Color _chartBackground = Color(0xFF141218);

  /// Everything on screen is re-read on this cadence, including the live candle.
  static const Duration _syncInterval = Duration(seconds: 10);

  /// How often the server is asked whether a training run has finished.
  static const Duration _queueInterval = Duration(seconds: 2);

  /// A single iteration is enough to refresh a model; the queue does the rest.
  static const TrainingRequest _quickTraining = TrainingRequest(
    iterations: 1,
    maxTradeHorizon: 288,
    takeProfitPercentage: 1,
    stopLossPercentage: 1,
  );

  final LocalStore _store = LocalStore();
  late final BinanceApi _binance = BinanceApi();
  late final OvermindApi _overmind = OvermindApi();
  late final ApiKeyStore _apiKeyStore;
  late final TradeSettingsStore _settingsStore;
  late final CandleService _candleService;
  late final PositionTracker _tracker;
  late final TradingService _trading;
  late final SoundCue _sound = SoundCue();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final PeriodicTask _sync = PeriodicTask(
    interval: _syncInterval,
    onTick: _syncScreen,
    onError: (error) => logError('refreshing the dashboard', error),
  );

  late final PeriodicTask _autoTrade = PeriodicTask(
    interval: _syncInterval,
    fireImmediately: false,
    onTick: _tradePortfolioAutomatically,
    onError: (error) => logError('automatic trading', error),
  );

  PeriodicTask? _queueCheck;
  PeriodicTask? _serverRetry;

  ApiKeys _keys = ApiKeys.empty;
  TradeSettings _tradeSettings = TradeSettings.defaults;
  Portfolio _portfolio = Portfolio.empty;
  Map<String, double> _latestPrices = const {};
  List<String> _symbols = const [];
  CandleSeries _series = CandleSeries.empty;
  ChartState _chart = ChartState.none;
  OptimizationSettings _optimization = const OptimizationSettings();
  String _symbol = _defaultSymbol;
  bool _isAutoTrade = false;
  bool _trainedAtLeastOnce = true;

  @override
  void initState() {
    super.initState();
    _apiKeyStore = ApiKeyStore(store: _store);
    _settingsStore = TradeSettingsStore(store: _store);
    _candleService = CandleService(overmind: _overmind, binance: _binance);
    _tracker = PositionTracker(binance: _binance);
    _trading = TradingService(
      binance: _binance,
      overmind: _overmind,
      positions: _tracker,
    );

    initToasts(navigatorKey.currentContext!);
    _loadStoredSettings();
    UpdateChecker().checkForUpdates(context);
  }

  @override
  void dispose() {
    _sync.stop();
    _autoTrade.stop();
    _queueCheck?.stop();
    _serverRetry?.stop();
    _sound.dispose();
    _tracker.dispose();
    super.dispose();
  }

  /// Reads keys and trade sizing, then starts the dashboard.
  ///
  /// Missing keys open the key sheet instead of polling servers that cannot be
  /// authenticated against.
  Future<void> _loadStoredSettings() async {
    final keys = await _apiKeyStore.read();
    final settings = await _settingsStore.read();

    if (!mounted) return;
    setState(() {
      _keys = keys;
      _tradeSettings = settings;
    });

    if (!keys.isComplete) {
      _showApiKeysModal();
      return;
    }

    await _start();
  }

  Future<void> _start() async {
    await _tracker.refresh(_keys);
    try {
      await _refreshScreen();
      _sync.start();
    } catch (error) {
      logError('connecting to Overmind', error);
      _startServerRetry();
    }
  }

  /// Overlay levels for the selected symbol: recommended offsets from the
  /// portfolio plus the absolute levels resting on the exchange.
  void _applyLevels(String symbol) {
    setState(() {
      _chart = _chart.levelsFor(
        symbol,
        portfolio: _portfolio,
        timeframe: _timeframe,
        auxTimeframe: _auxTimeframe,
        positions: _tracker.current,
      );
    });
  }

  /// Portfolio, symbols and chart, in that order.
  ///
  /// Levels are applied before the candles load, so the live candle is priced
  /// off the side the current signal trades.
  Future<void> _refreshScreen() async {
    await _loadPortfolio();
    final symbols = await _overmind.getSymbols(_keys.overmindApiKey);

    if (!mounted) return;
    setState(() => _symbols = symbols);
    _applyLevels(_symbol);

    await _loadCandles();
  }

  /// Keeps the dashboard current: portfolio, prices, positions, overlays and the
  /// newest candle.
  Future<void> _syncScreen() async {
    await _loadPortfolio();
    await _tracker.refresh(_keys);
    if (!mounted) return;
    _applyLevels(_symbol);
    await _loadCandles();
  }

  /// Throws when the server is unreachable so the caller can retry.
  Future<Portfolio> _loadPortfolio({bool filterSignals = false}) async {
    final full = await _overmind.getPortfolio(_keys.overmindApiKey);
    final optimized = filterSignals ? full.filteredBest() : full;
    final prices = await _overmind.getLatestPrices(
      _keys.overmindApiKey,
      optimized.symbols,
    );

    if (!mounted) return Portfolio.empty;
    setState(() {
      _portfolio = full;
      _latestPrices = prices;
    });
    return optimized;
  }

  Future<void> _loadCandles() async {
    final series = await _candleService.load(
      symbol: _symbol,
      timeframe: _timeframe,
      keys: _keys,
      preferBid: _chart.preferBid,
    );

    if (!mounted) return;
    setState(() {
      _series = series;
      _chart = _chart.copyWith(lastClose: series.lastClose);
    });
  }

  /// Re-reads portfolio, symbols and candles until the server answers.
  void _startServerRetry() {
    _serverRetry?.stop();
    _serverRetry = PeriodicTask(
      interval: _syncInterval,
      fireImmediately: false,
      onTick: () async {
        await _refreshScreen();
        _serverRetry?.stop();
        _sync.start();
        showToast('Successfully connected to Overmind servers');
      },
      onError: (error) {
        showToast(
          "Couldn't connect to Overmind servers. "
          'Retrying in ${_syncInterval.inSeconds} seconds...',
        );
        logError('retrying the Overmind connection', error);
      },
    );
    _serverRetry!.start();
  }

  /// Watches the training queue until the run leaves it, then re-enables the
  /// auto trader.
  void _watchTrainingQueue() {
    if (_queueCheck?.isRunning ?? false) return;

    _queueCheck = PeriodicTask(
      interval: _queueInterval,
      fireImmediately: false,
      onTick: () async {
        if (await _overmind.isTrainInQueue(_keys.overmindApiKey)) return;
        _queueCheck?.stop();
        if (!mounted) return;
        setState(() => _trainedAtLeastOnce = true);
        if (!_isAutoTrade) await _sound.playTrainingComplete();
        showToast('Training complete');
      },
    );
    _queueCheck!.start();
  }

  /// Asks the server to train, without blocking on the queue.
  Future<Portfolio> _requestTraining() async {
    showToast('Requesting to train portfolio');
    _watchTrainingQueue();

    if (await _overmind.isTrainInQueue(_keys.overmindApiKey)) {
      showToast('Already in training queue');
      return _portfolio;
    }

    await _overmind.trainPortfolio(_keys.overmindApiKey, _quickTraining);
    showToast('Request to train portfolio added to the queue');
    return _portfolio;
  }

  /// Runs a training request against the whole portfolio, or against the models
  /// whose testing score is below what the settings require.
  Future<void> _runTraining(TrainingRequest request,
      {required bool subparModels}) async {
    final symbols = subparModels ? _subparSymbols() : null;
    if (symbols != null && symbols.isEmpty) {
      showToast('No subpar models to train');
      return;
    }

    final trained = symbols == null
        ? await _overmind.trainPortfolio(_keys.overmindApiKey, request)
        : await _overmind.trainSymbols(_keys.overmindApiKey, request, symbols);

    if (!mounted) return;
    setState(() => _portfolio = trained);
    _watchTrainingQueue();
    showToast(subparModels ? 'Training subpar models' : 'Training portfolio');
  }

  Future<Portfolio> _trainModels(
      List<String> symbols, TrainingRequest request) async {
    if (symbols.isEmpty) {
      showToast('No models to train');
      return _portfolio;
    }

    final trained =
        await _overmind.trainSymbols(_keys.overmindApiKey, request, symbols);
    _watchTrainingQueue();
    if (!mounted) return trained;
    setState(() => _portfolio = trained);
    return trained;
  }

  /// Signals whose testing score is below what the settings require.
  List<String> _subparSymbols() =>
      _portfolio.subpar(_optimization.minTestingScore).symbols;

  Future<Portfolio> _resetPortfolio() async {
    try {
      final reset = await _overmind.resetPortfolio(_keys.overmindApiKey);
      if (!mounted) return reset;
      setState(() => _portfolio = reset);
      showSnackBar(context, 'Your portfolio has been reset',
          backgroundColor: Colors.black);
      return reset;
    } catch (error) {
      if (!mounted) return Portfolio.empty;
      showSnackBar(context, 'Failed to reset portfolio: $error',
          backgroundColor: Colors.red);
      return Portfolio.empty;
    }
  }

  Future<Portfolio> _resetSubparModels() async {
    final symbols = _subparSymbols();
    if (symbols.isEmpty) {
      showSnackBar(context, 'No subpar models to reset');
      return _portfolio;
    }

    try {
      final reset = await _overmind.resetModels(_keys.overmindApiKey, symbols);
      if (!mounted) return reset;
      setState(() => _portfolio = reset);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subpar models have been reset (${symbols.length})'),
          backgroundColor: Colors.white,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.black,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return reset;
    } catch (error) {
      if (!mounted) return Portfolio.empty;
      showSnackBar(context, 'Failed to reset subpar models: $error',
          backgroundColor: Colors.red);
      return Portfolio.empty;
    }
  }

  Future<Portfolio> _resetModel(Holding holding) async {
    final reset =
        await _overmind.resetModel(_keys.overmindApiKey, holding.instrument);
    if (!mounted) return reset;
    setState(() => _portfolio = reset);
    return reset;
  }

  Future<Portfolio> _trainModel(Holding holding) async {
    return _trainModels([holding.instrument], _quickTraining);
  }

  /// Trades every signal that is not already held, sized by the stored settings.
  Future<void> _tradePortfolioAutomatically() async {
    if (!_trainedAtLeastOnce) return;

    final tradable = await _loadPortfolio(filterSignals: true);
    if (tradable.isEmpty) return;

    final outcomes =
        await _trading.executePortfolio(_keys, tradable, _tradeSettings);
    for (final outcome in outcomes.where((outcome) => outcome.success)) {
      showToast(outcome.message);
    }
  }

  /// The holding the dashboard trades for [symbol], or a flat one when the
  /// symbol has no signal yet.
  Holding _holdingFor(String symbol) =>
      _portfolio.holdingFor(symbol, _timeframe) ??
      Holding.noSignal(symbol, _timeframe);

  Future<ActionResult> _updateTakeProfit(String symbol) =>
      _trading.updateTakeProfit(_keys, symbol, _holdingFor(symbol));

  Future<ActionResult> _updateStopLoss(String symbol) =>
      _trading.updateStopLoss(_keys, symbol, _holdingFor(symbol));

  Future<ActionResult> _updateBoth(String symbol) =>
      _trading.updateBoth(_keys, symbol, _holdingFor(symbol));

  Future<ActionResult> _closePosition(String symbol) =>
      _trading.closePosition(_keys, symbol);

  /// Selecting a symbol re-reads its overlay levels and its candles.
  ///
  /// A failed candle load is reported here rather than escaping as an
  /// unhandled error, because the selection comes from a button press.
  void _selectSymbol(String symbol) {
    setState(() => _symbol = symbol);
    _applyLevels(symbol);
    _loadCandlesQuietly();
  }

  Future<void> _loadCandlesQuietly() async {
    try {
      await _loadCandles();
    } catch (error) {
      showToast('Could not load candles for $_symbol');
      logError('loading candles for $_symbol', error);
    }
  }

  void _toggleAutoTrade() {
    final starting = !_isAutoTrade;
    setState(() => _isAutoTrade = starting);

    if (starting) {
      _autoTrade.start();
      showSnackBar(context, 'Starting automatic trading');
    } else {
      _autoTrade.stop();
      showSnackBar(context, 'Stopping automatic trading');
    }
  }

  Future<void> _saveKeys(ApiKeys keys) async {
    await _apiKeyStore.write(keys);
    if (!mounted) return;
    setState(() => _keys = keys);
    if (keys.isComplete) await _start();
  }

  /// Requests a free-tier key and stores it immediately, so the dashboard can
  /// connect before the user presses save.
  Future<String> _requestFreeTierKey() async {
    final key = await _overmind.getFreeTierApiKey();
    await _apiKeyStore.write(_keys.copyWith(overmindApiKey: key));
    if (!mounted) return key;
    setState(() => _keys = _keys.copyWith(overmindApiKey: key));
    return key;
  }

  void _showApiKeysModal() {
    showSheet(
      context,
      ApiKeysModal(
        keys: _keys,
        onRequestFreeTierKey: _requestFreeTierKey,
        onSave: _saveKeys,
      ),
    );
  }

  void _showTrainingModal({required bool subparModels}) {
    showSheet(
      context,
      TrainingModal(
        onStartTraining: (request) =>
            _runTraining(request, subparModels: subparModels),
      ),
    );
  }

  void _showOptimizationSettings() {
    showSheet(
      context,
      OptimizationSettingsModal(
        initialSettings: _optimization,
        onSettingsChanged: (settings) =>
            setState(() => _optimization = settings),
      ),
    );
  }

  void _showTradeHistory() {
    showDialog(
      context: context,
      builder: (_) => TradeHistoryDialog(
        fetchTrades: (start, end) => _binance.getUserTrades(_keys, start, end),
      ),
    );
  }

  void _openDashboard() {
    if (_portfolio.isEmpty || _tracker.current.isEmpty) {
      showSnackBar(context, 'Portfolio data is still loading. Please wait.');
      return;
    }
    _scaffoldKey.currentState?.openDrawer();
  }

  void _persistTradeSettings(TradeSettings settings) {
    setState(() => _tradeSettings = settings);
    _settingsStore.write(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerScrimColor: Colors.transparent,
      appBar: AppBar(
        // The menu bar replaces the title area; the app name lives in the sheet.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: TopMenuBar(
            onOptimizedPortfolio: _openDashboard,
            onTradeHistory: _showTradeHistory,
            onOptimizationSettings: _showOptimizationSettings,
            onTrainPortfolio: () => _showTrainingModal(subparModels: false),
            onTrainSubparModels: () => _showTrainingModal(subparModels: true),
            onResetPortfolio: _resetPortfolio,
            onResetSubparModels: _resetSubparModels,
            onApiKeys: _showApiKeysModal,
            onToggleAutoTrade: _toggleAutoTrade,
            onSymbolSelected: _selectSymbol,
            symbols: _symbols,
            selectedSymbol: _symbol,
            isAutoTrade: _isAutoTrade,
          ),
        ),
      ),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.45,
        child: OptimizedPortfolioDialog(
          portfolio: _portfolio,
          latestPrices: _latestPrices,
          positions: _tracker.positions,
          tradeSettings: _tradeSettings,
          onTradeSettingsChanged: _persistTradeSettings,
          actions: PortfolioActions(
            trainPortfolio: _requestTraining,
            resetPortfolio: _resetPortfolio,
            trainModel: _trainModel,
            resetModel: _resetModel,
            tradeHolding: (holding) => _trading.openPosition(
              _keys,
              holding,
              _tradeSettings.allocationUsdt,
              _tradeSettings.leverage,
            ),
            selectSymbol: _selectSymbol,
            updateTakeProfit: _updateTakeProfit,
            updateStopLoss: _updateStopLoss,
            updateBoth: _updateBoth,
            closePosition: _closePosition,
          ),
        ),
      ),
      body: Container(
        color: _chartBackground,
        child: _chartBody(),
      ),
    );
  }

  Widget _chartBody() {
    if (_series.isEmpty)
      return const Center(child: CircularProgressIndicator());

    return InteractiveChart(
      style: ChartStyle(
        priceGainColor: Colors.white,
        priceLossColor: Colors.black,
        trendLineStyles: [
          Paint()
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..color = Colors.deepOrange,
        ],
      ),
      candles: _series.candles,
      amheragHeight: _series.amheragHeight,
      tp: _chart.takeProfitPrice,
      sl: _chart.stopLossPrice,
      newTp: _chart.plannedTakeProfit,
      newSl: _chart.plannedStopLoss,
      auxTp: _chart.auxTakeProfit,
      auxSl: _chart.auxStopLoss,
      entryPrice: _chart.entryPrice,
      lastClose: _chart.lastClose,
    );
  }
}
