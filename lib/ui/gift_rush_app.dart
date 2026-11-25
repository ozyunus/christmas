import 'dart:async';
import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_config.dart';
import '../game/shift_catalog.dart';
import '../game/shift_session.dart';
import '../platform/analytics.dart';
import '../platform/holiday_audio.dart';
import '../platform/local_save.dart';
import 'factory_scene.dart';
import 'factory_widgets.dart';
import 'game_layout.dart';
import 'shift_flight_transition.dart';
import 'shift_widgets.dart';

const gameTitle = "Santa's Gift Rush";

enum _MenuPage { home, campaign, roadTrip, help }

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
    required this.content,
    required this.factoryImages,
    required this.repository,
    this.initialSave = const LocalSave(),
    this.analytics = const NoOpAnalyticsService(),
    this.audio = const PlatformHolidayAudio(),
    this.clockMs,
    this.now,
    this.loadError = false,
  });

  final ShiftCatalog content;
  final Images factoryImages;
  final LocalSaveRepository repository;
  final LocalSave initialSave;
  final AnalyticsService analytics;
  final HolidayAudio audio;
  final int Function()? clockMs;
  final DateTime Function()? now;
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
  ShiftDefinition? _flightDestination;
  bool _inShift = false;
  _MenuPage _menuPage = _MenuPage.home;
  bool _storageError = false;
  late int _bestScore;
  late int _sessionIndex;
  ShiftResult? _latestResult;
  late final Set<String> _completedShifts;
  DailyRecord? _dailyRecord;
  late bool _musicEnabled;
  late bool _foreground;
  int _baselineMs = 0;
  int _resumedAtMs = 0;
  int? _swipeGift;
  double _swipeDistance = 0;

  int get _clockMs => widget.clockMs?.call() ?? _stopwatch.elapsedMilliseconds;
  DateTime _now() => widget.now?.call() ?? DateTime.now();

  ShiftDefinition _definition(ShiftSessionController shift) =>
      widget.content.byVersion[shift.config.version]!;

  String get _dailyRecordVersion =>
      _dailyRecord?.rulesVersion ?? widget.content.legacyDailyVersion;

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
    _completedShifts = save.completedShifts.toSet();
    _dailyRecord = save.dailyRecord;
    _musicEnabled = save.musicEnabled;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.audio.setMusicPlaying(_foreground && _musicEnabled);
    final checkpoint = save.unfinishedShift;
    if (checkpoint != null) {
      try {
        final definition = widget.content.byVersion[checkpoint.configVersion];
        if (definition == null) {
          throw const FormatException('Saved shift is unavailable.');
        }
        _shift = ShiftSessionController.restore(
          config: definition.rules,
          checkpoint: checkpoint,
          events: _events,
          now: _now,
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
    final foreground = state == AppLifecycleState.resumed;
    if (foreground != _foreground) {
      _foreground = foreground;
      widget.audio.setMusicPlaying(_foreground && _musicEnabled);
    }
    if (!foreground) {
      _pause(PauseReason.background);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.setMusicPlaying(false);
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
        final definition = _definition(shift);
        switch (definition.mode) {
          case ShiftMode.arcade:
            _bestScore = max(_bestScore, result.stats.score);
          case ShiftMode.daily:
            final existing = _dailyRecord;
            if (existing == null ||
                existing.day != shift.seed ||
                _dailyRecordVersion != shift.config.version ||
                result.stats.score > existing.score) {
              _dailyRecord = DailyRecord(
                shift.seed,
                result.stats.score,
                rulesVersion: shift.config.version,
              );
            }
          case ShiftMode.campaign:
            if (definition.goal!.isMet(result.stats)) {
              _completedShifts.add(definition.id);
            }
          case ShiftMode.regional:
            break;
        }
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

  void _newShift(
    ShiftDefinition definition, {
    String? previousRoundId,
    int? seed,
  }) {
    final now = _now();
    final shift = ShiftSessionController(
      config: definition.rules,
      roundId: '${now.microsecondsSinceEpoch}-${++_sessionIndex}',
      seed:
          seed ??
          (definition.mode == ShiftMode.daily
              ? ShiftCatalog.daySeed(now)
              : _random.nextInt(2147483646)),
      sessionIndex: _sessionIndex,
      events: _events,
      now: _now,
    );
    setState(() {
      _shift = shift;
      _flightDestination = null;
      _scene = FactoryScene(
        shift: shift,
        beltSurges: definition.beltSurges,
        factoryImages: widget.factoryImages,
      );
      _inShift = true;
    });
    shift.start(previousRoundId: previousRoundId);
    _startClock(shift);
    _save();
  }

  void _flyTo(ShiftDefinition next) {
    if (_flightDestination != null) return;
    setState(() => _flightDestination = next);
    if (_foreground && _musicEnabled) widget.audio.playSleighBells();
  }

  void _toggleMusic() {
    setState(() => _musicEnabled = !_musicEnabled);
    widget.audio.setMusicPlaying(_foreground && _musicEnabled);
    _save();
  }

  Future<void> _selectShift(ShiftDefinition definition) async {
    if (_shift?.status != ShiftStatus.paused) {
      _newShift(definition);
      return;
    }
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
    if (mounted && replace == true) _newShift(definition);
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
        beltSurges: _definition(shift).beltSurges,
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
    setState(() {
      _inShift = false;
      _menuPage = _MenuPage.home;
    });
  }

  void _openMenuPage(_MenuPage page) => setState(() => _menuPage = page);

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
      completedShifts: Set.unmodifiable(_completedShifts),
      dailyRecord: _dailyRecord,
      musicEnabled: _musicEnabled,
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
    final flightDestination = _flightDestination;
    final hasUnfinished = shift?.status == ShiftStatus.paused;
    final showGameplay = _inShift && shift != null && shift.result == null;
    return PopScope(
      canPop: flightDestination == null,
      child: Scaffold(
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
                  footer: _musicToggle(),
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
            if (flightDestination != null)
              ShiftFlightTransition(
                destination: flightDestination.title,
                sleigh: widget.factoryImages.fromCache(santaSleighAsset),
                onFinished: () => _newShift(flightDestination),
              )
            else if (_inShift && shift?.result != null)
              _results(shift!),
            if (!_inShift)
              switch (_menuPage) {
                _MenuPage.home => _menu(hasUnfinished),
                _MenuPage.campaign => _campaignMenu(),
                _MenuPage.roadTrip => _roadTripMenu(),
                _MenuPage.help => _help(),
              },
          ],
        ),
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
    final definition = _definition(shift);
    final goal = definition.goal;
    final surge = definition.beltSurges.stateAt(shift.elapsedMs);
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
              child: Column(
                children: [
                  GameHud(
                    stats: shift.stats,
                    secondsLeft: _seconds(shift),
                    onPause: () => _pause(PauseReason.manual),
                  ),
                  if (goal != null) ...[
                    const SizedBox(height: 8),
                    ShiftGoals(goal: goal, stats: shift.stats, onBelt: true),
                  ],
                  if (surge != BeltSurgeState.calm) ...[
                    const SizedBox(height: 6),
                    BeltSurgeNotice(state: surge),
                  ],
                ],
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
    final daily = _dailyRecord;
    return FactoryPanel(
      art: PanelArt.menu,
      title: gameTitle,
      footer: Row(
        children: [
          Expanded(
            child: FactoryAction(
              label: 'How to Play',
              secondary: true,
              onPressed: () => _openMenuPage(_MenuPage.help),
            ),
          ),
          Expanded(child: _musicToggle()),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Arcade Best  $_bestScore',
            style: const TextStyle(
              fontSize: 18,
              color: evergreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (daily != null &&
              daily.day == ShiftCatalog.daySeed(_now()) &&
              _dailyRecordVersion == widget.content.daily.rules.version)
            Text('Daily Best  ${daily.score}'),
          const SizedBox(height: 10),
          if (hasUnfinished)
            FactoryAction(label: 'Resume Shift', onPressed: _resume),
          FactoryAction(
            label: 'Play Shifts',
            secondary: hasUnfinished,
            onPressed: () => _openMenuPage(_MenuPage.campaign),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              FactoryAction(
                label: 'Arcade',
                secondary: true,
                onPressed: () => _selectShift(widget.content.arcade),
              ),
              FactoryAction(
                label: 'Daily Shift',
                secondary: true,
                onPressed: () => _selectShift(widget.content.daily),
              ),
            ],
          ),
          FactoryAction(
            label: "Santa's Road Trip",
            secondary: true,
            onPressed: () => _openMenuPage(_MenuPage.roadTrip),
          ),
          if (_storageError)
            const Text('Some local progress may be unavailable.'),
        ],
      ),
    );
  }

  Widget _musicToggle() => Semantics(
    toggled: _musicEnabled,
    child: FactoryAction(
      label: _musicEnabled ? 'Music On' : 'Music Off',
      secondary: true,
      onPressed: _toggleMusic,
    ),
  );

  Widget _campaignMenu() => CampaignMenu(
    content: widget.content,
    completed: _completedShifts,
    onSelect: _selectShift,
    onBack: _showMenu,
  );

  Widget _roadTripMenu() => RoadTripMenu(
    previews: widget.content.regionalPreviews,
    onSelect: _selectShift,
    onBack: _showMenu,
  );

  Widget _help() {
    return FactoryPanel(
      art: PanelArt.tutorial,
      title: 'How to Play',
      footer: FactoryAction(
        label: 'Back',
        secondary: true,
        onPressed: _showMenu,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Sort Santa's nice and naughty gifts before the clock runs out.",
          ),
          const SizedBox(height: 10),
          const Text(
            'Swipe left or tap $shipLabel for good gifts like the bear, toy drum, or sailboat.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Swipe right or tap $rejectLabel for coal, a burnt cookie, or a broken toy.',
          ),
          const SizedBox(height: 8),
          const Text('Wrong answers and missed gifts reset your combo.'),
        ],
      ),
    );
  }

  Widget _results(ShiftSessionController shift) {
    final definition = _definition(shift);
    final result = shift.result!;
    final stats = result.stats;
    final goal = definition.goal;
    final passed = goal?.isMet(stats) ?? false;
    final hasOrder = goal?.shipped.isNotEmpty == true;
    final next = passed ? widget.content.nextAfter(definition) : null;
    final campaignComplete =
        passed && definition.mode == ShiftMode.campaign && next == null;
    final (title, primaryLabel) = switch (definition.mode) {
      ShiftMode.campaign when campaignComplete => (
        'Campaign Complete',
        'Play Arcade',
      ),
      ShiftMode.campaign when passed => ('Shift Cleared', 'Next Shift'),
      ShiftMode.campaign => ('Goal Missed', 'Retry'),
      ShiftMode.regional when passed => (
        hasOrder ? 'Order Complete' : 'Shift Cleared',
        'Play Again',
      ),
      ShiftMode.regional => (
        hasOrder ? 'Order Incomplete' : 'Goal Missed',
        'Retry',
      ),
      _ => ('Shift Complete', 'Play Again'),
    };
    return FactoryPanel(
      art: PanelArt.results,
      title: title,
      footer: FactoryAction(
        label: primaryLabel,
        onPressed: () {
          if (next != null) {
            _flyTo(next);
          } else if (campaignComplete) {
            _newShift(widget.content.arcade);
          } else {
            _newShift(
              widget.content.retryDefinitionFor(definition),
              previousRoundId: result.roundId,
              seed: definition.mode == ShiftMode.daily ? shift.seed : null,
            );
          }
        },
      ),
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
          if (goal != null) ShiftGoals(goal: goal, stats: stats),
          if (campaignComplete)
            FactoryAction(
              label: 'Daily Shift',
              secondary: true,
              onPressed: () => _newShift(widget.content.daily),
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
