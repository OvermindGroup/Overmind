import 'dart:async';

import '../utils/log.dart';

/// A recurring background job: position polling, server retries, queue checks.
///
/// Ticks are serialised so a slow request cannot overlap the next one, which
/// `Stream.periodic(...).listen(async ...)` allowed to happen.
class PeriodicTask {
  PeriodicTask({
    required this.interval,
    required this.onTick,
    this.onError,
    this.fireImmediately = true,
  });

  final Duration interval;
  final Future<void> Function() onTick;
  final void Function(Object error)? onError;

  /// Matches `Stream.periodic`, whose first event arrives immediately.
  final bool fireImmediately;

  Timer? _timer;
  bool _busy = false;

  bool get isRunning => _timer != null;

  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(interval, (_) => _tick());
    if (fireImmediately) _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await onTick();
    } catch (error) {
      if (onError != null) {
        onError!(error);
      } else {
        logError('periodic task', error);
      }
    } finally {
      _busy = false;
    }
  }
}
