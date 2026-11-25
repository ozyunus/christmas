import 'dart:async';
import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_config.dart';
import '../game/shift_session.dart';
import '../platform/analytics.dart';
import '../platform/local_save.dart';
import 'factory_scene.dart';
import 'factory_widgets.dart';
import 'game_layout.dart';

const gameTitle = "Santa's Gift Rush";

ThemeData factoryTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: evergreen),
    scaffoldBackgroundColor: const Color(0xFF162B24),
    useMaterial3: true,
  );
}

class GiftRushApp extends StatefulWidget {
  const GiftRushApp({
    super.key,
    required this.config,
    required this.factoryImages,
    required this.repository,
    this.initialSave = const LocalSave(),
    this.analytics = const NoOpAnalyticsService(),
    this.clockMs,
    this.loadError = false,
  });

  final GameConfig config;
  final Images factoryImages;
  final LocalSaveRepository repository;
  final LocalSave initialSave;
  final AnalyticsService analytics;
  final int Function()? clockMs;
  final bool loadError;

  @override
  State<GiftRushApp> createState() => _GiftRushAppState();
}

class _GiftRushAppState extends State<GiftRushApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _events = GameEventBus();
  final _stopwatch = Stopwatch()..start();
  final _random = Random();
  late final Ticker _ticker;
  late final StreamSubscription<ShiftEvent> _eventSubscription;
  late final ShiftTelemetry _telemetry;

  ShiftSessionController? _shift;
  FactoryScene? _scene;
  bool _inShift = false;
  bool _showHelp = false;
  bool _storageError = false;
  late int _bestScore;
  late int _sessionIndex;
  ShiftResult? _latestResult;
  int _baselineMs = 0;
  int _resumedAtMs = 0;
  int? _swipeGift;
  double _swipeDistance = 0;

  int get _clockMs => widget.clockMs?.call() ?? _stopwatch.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _storageError = widget.loadError;
    _telemetry = ShiftTelemetry(widget.analytics);
    _ticker = createTicker((_) => _syncClock());
    _eventSubscription = _events.events.listen((event) {
      _telemetry.record(_shift!, event);
    });
    WidgetsBinding.instance.addObserver(this);

    final save = widget.initialSave;
    _bestScore = save.bestScore;
    _sessionIndex = save.sessionIndex;
    _latestResult = save.latestResult;
    final checkpoint = save.unfinishedShift;
    if (checkpoint != null) {
      try {
        _shift = ShiftSessionController.restore(
          config: widget.config,
          checkpoint: checkpoint,
          events: _events,
        );
      } on FormatException {
        _storageError = true;
        _recordStorageIssue('read');
      }
    }
    if (widget.loadError) _recordStorageIssue('read');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause(PauseReason.background);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    unawaited(_eventSubscription.cancel());
    unawaited(_events.dispose());
    super.dispose();
  }

  void _startClock(ShiftSessionController shift) {
    _baselineMs = shift.elapsedMs;
    _resumedAtMs = _clockMs;
    _ticker.start();
  }

  void _syncClock() {
    final shift = _shift;
    if (shift == null || shift.status != ShiftStatus.playing) return;
    final previousSeconds = _seconds(shift);
    final previousGift = shift.activeGift?.index;
    final previousStats = shift.stats;
    shift.advanceTo(_baselineMs + max(0, _clockMs - _resumedAtMs));
    final result = shift.result;
    if (result != null) {
      _ticker.stop();
      setState(() {
        _latestResult = result;
        _bestScore = max(_bestScore, result.stats.score);
      });
      _save();
      return;
    }
    final secondsChanged = previousSeconds != _seconds(shift);
    final statsChanged = previousStats != shift.stats;
    if (secondsChanged ||
        statsChanged ||
        previousGift != shift.activeGift?.index) {
      setState(() {});
    }
    if (secondsChanged || statsChanged) _save();
  }

  void _newShift({String? previousRoundId}) {
    final shift = ShiftSessionController(
      config: widget.config,
      roundId: '${DateTime.now().microsecondsSinceEpoch}-${++_sessionIndex}',
      seed: _random.nextInt(2147483646),
      sessionIndex: _sessionIndex,
      events: _events,
    );
    setState(() {
      _shift = shift;
      _scene = FactoryScene(shift: shift, factoryImages: widget.factoryImages);
      _inShift = true;
    });
    shift.start(previousRoundId: previousRoundId);
    _startClock(shift);
    _save();
  }

  Future<void> _confirmNewShift() async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new shift?'),
        content: const Text('Your unfinished shift will be replaced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start New Shift'),
          ),
        ],
      ),
    );
    if (mounted && replace == true) _newShift();
  }

  void _pause(PauseReason reason) {
    _syncClock();
    final shift = _shift;
    if (shift == null || shift.status != ShiftStatus.playing) return;
    _ticker.stop();
    shift.pause(reason);
    _scene?.pauseEngine();
    setState(() {});
    _save();
  }

  void _resume() {
    final shift = _shift;
    if (shift == null || shift.status != ShiftStatus.paused) return;
    setState(() {
      _scene ??= FactoryScene(
        shift: shift,
        factoryImages: widget.factoryImages,
      );
      _inShift = true;
    });
    shift.resume();
    _scene!.resumeEngine();
    _startClock(shift);
    _save();
  }

  void _showMenu() {
    // A paused shift remains available from the menu.
    setState(() => _inShift = false);
  }

  void _choose(int index, GiftClass choice, InputMethod method) {
    _syncClock();
    if (_shift?.sort(giftIndex: index, choice: choice, method: method) ??
        false) {
      setState(() {});
      _save();
    }
  }

  int _seconds(ShiftSessionController shift) =>
      (shift.remainingMs + 999) ~/ 1000;

  void _save() {
    final shift = _shift;
    final checkpoint = shift == null || shift.status == ShiftStatus.completed
        ? null
        : shift.checkpoint();
    final save = LocalSave(
      bestScore: _bestScore,
      sessionIndex: _sessionIndex,
      latestResult: _latestResult,
      unfinishedShift: checkpoint,
    );
    unawaited(
      widget.repository.save(save).catchError((Object _, StackTrace _) {
        if (mounted && !_storageError) {
          _recordStorageIssue('write');
          setState(() => _storageError = true);
        }
      }),
    );
  }

  void _recordStorageIssue(String operation) {
    _telemetry.dispatch(
      AnalyticsEvent(AnalyticsEventName.appErrorContext, {
        'scene_id': _inShift ? 'gameplay' : 'menu',
        'error_category': 'local_save_$operation',
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = ResponsiveGameLayout(media.size, media.padding);
    final shift = _shift;
    final hasUnfinished = shift?.status == ShiftStatus.paused;
    final showGameplay = _inShift && shift != null && shift.result == null;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FactoryBackground(layout: layout, isPlaying: showGameplay),
          if (showGameplay) _gameplay(layout, shift, media.disableAnimations),
          if (showGameplay && hasUnfinished)
            ColoredBox(
              color: Colors.black54,
              child: FactoryPanel(
                art: PanelArt.pause,
                title: 'Shift Paused',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shift.pauseReason == PauseReason.background
                          ? 'Your shift is ready when you are.'
                          : 'The clock is paused.',
                    ),
                    const SizedBox(height: 10),
                    FactoryAction(label: 'Resume Shift', onPressed: _resume),
                    FactoryAction(
                      label: 'Main Menu',
                      onPressed: _showMenu,
                      secondary: true,
                    ),
                  ],
                ),
              ),
            ),
          if (_inShift && shift?.result != null) _results(shift!.result!),
          if (!_inShift && _showHelp) _help(),
          if (!_inShift && !_showHelp) _menu(hasUnfinished),
        ],
      ),
    );
  }

  Widget _gameplay(
    ResponsiveGameLayout layout,
    ShiftSessionController shift,
    bool reduceMotion,
  ) {
    final scene = _scene!
      ..layout = layout
      ..reduceMotion = reduceMotion;
    final playing = shift.status == ShiftStatus.playing;
    final gift = shift.activeGift;
    final arena = layout.arena;
    final swipeArea = layout.swipeArea;
    final decisionWidth = min(
      (arena.width - 12) / 2,
      layout.isTablet ? 246.0 : 200.0,
    );
    final decisionHeight = max(52.0, decisionWidth / 2);
    return ExcludeSemantics(
      excluding: !playing,
      child: IgnorePointer(
        ignoring: !playing,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(child: GameWidget(game: scene)),
            Positioned.fromRect(
              rect: swipeArea,
              child: Semantics(
                label: gift?.gift.id.replaceAll('_', ' '),
                child: GestureDetector(
                  key: const ValueKey('gift-arena'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: (_) {
                    _swipeGift = gift?.index;
                    _swipeDistance = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    _swipeDistance += details.primaryDelta ?? 0;
                  },
                  onHorizontalDragCancel: () => _swipeGift = null,
                  onHorizontalDragEnd: (details) {
                    final index = _swipeGift;
                    _swipeGift = null;
                    if (index == null) return;
                    final fast = (details.primaryVelocity ?? 0).abs() >= 240;
                    if (_swipeDistance.abs() >= 28 ||
                        (fast && _swipeDistance.abs() >= 10)) {
                      _choose(
                        index,
                        _swipeDistance < 0 ? GiftClass.nice : GiftClass.naughty,
                        InputMethod.swipe,
                      );
                    }
                  },
                ),
              ),
            ),
            Positioned(
              top: arena.top + 9,
              left: arena.left,
              width: arena.width,
              child: GameHud(
                stats: shift.stats,
                secondsLeft: _seconds(shift),
                onPause: () => _pause(PauseReason.manual),
              ),
            ),
            Positioned(
              left: arena.center.dx - decisionWidth - 6,
              bottom: MediaQuery.paddingOf(context).bottom + 9,
              child: Row(
                children: [
                  for (final choice in GiftClass.values) ...[
                    if (choice == GiftClass.naughty) const SizedBox(width: 12),
                    SizedBox(
                      width: decisionWidth,
                      height: decisionHeight,
                      child: DecisionButton(
                        key: ValueKey(choice.name),
                        choice: choice,
                        giftIndex: playing ? gift?.index : null,
                        onChoose: (index, selection) =>
                            _choose(index, selection, InputMethod.button),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(bool hasUnfinished) {
    return FactoryPanel(
      art: PanelArt.menu,
      title: gameTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/ui/icons/icon_gift.png',
            width: 55,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Best Score  $_bestScore',
            style: const TextStyle(
              fontSize: 18,
              color: evergreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (hasUnfinished) ...[
            FactoryAction(label: 'Resume Shift', onPressed: _resume),
            FactoryAction(
              label: 'New Shift',
              secondary: true,
              onPressed: _confirmNewShift,
            ),
          ] else
            FactoryAction(label: 'Start Shift', onPressed: _newShift),
          FactoryAction(
            label: 'How to Play',
            secondary: true,
            onPressed: () => setState(() => _showHelp = true),
          ),
          if (_storageError)
            const Text('Some local progress may be unavailable.'),
        ],
      ),
    );
  }

  Widget _help() {
    return FactoryPanel(
      art: PanelArt.tutorial,
      title: 'How to Play',
      footer: FactoryAction(
        label: 'Back',
        secondary: true,
        onPressed: () => setState(() => _showHelp = false),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sort as many gifts as you can in 60 seconds.'),
          const SizedBox(height: 10),
          const Text(
            'Swipe left or tap NICE for the bear, train, candy cane, or robot.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Swipe right or tap NAUGHTY for coal, socks, the spider, or broken ornament.',
          ),
          const SizedBox(height: 8),
          const Text('Wrong answers and missed gifts reset your combo.'),
        ],
      ),
    );
  }

  Widget _results(ShiftResult result) {
    final stats = result.stats;
    return FactoryPanel(
      art: PanelArt.results,
      title: 'Shift Complete',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats.score}',
            style: const TextStyle(
              fontSize: 39,
              height: 1,
              color: evergreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Final Score',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _resultMetric('Accuracy', '${stats.accuracyPercent.round()}%'),
              _resultMetric('Best Combo', '${stats.bestCombo}'),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _resultMetric('Correct', '${stats.correct}'),
              _resultMetric('Incorrect', '${stats.wrong}'),
              _resultMetric('Missed', '${stats.missed}'),
            ],
          ),
          const SizedBox(height: 8),
          FactoryAction(
            label: 'Play Again',
            onPressed: () => _newShift(previousRoundId: result.roundId),
          ),
          FactoryAction(
            label: 'Main Menu',
            onPressed: _showMenu,
            secondary: true,
          ),
        ],
      ),
    );
  }

  Widget _resultMetric(String name, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
