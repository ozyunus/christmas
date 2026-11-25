import 'dart:async';
import 'dart:math';

import 'game_config.dart';

const giftExitDurationMs = 180;

enum ShiftStatus { playing, paused, completed }

enum InputMethod { button, swipe }

enum GiftOutcome { correct, wrong, missed }

enum PauseReason { manual, background, restored }

final class ActiveGift {
  const ActiveGift({
    required this.index,
    required this.gift,
    required this.spawnedAtMs,
    required this.phaseIndex,
    required this.deadlineMs,
  });

  final int index;
  final Gift gift;
  final int spawnedAtMs;
  final int phaseIndex;
  final int deadlineMs;

  int get expiresAtMs => spawnedAtMs + deadlineMs;
}

final class ShiftStats {
  const ShiftStats({
    this.score = 0,
    this.combo = 0,
    this.bestCombo = 0,
    this.correct = 0,
    this.wrong = 0,
    this.missed = 0,
  });

  factory ShiftStats.fromJson(Map<String, dynamic> json) => ShiftStats(
    score: json['score'] as int,
    combo: json['combo'] as int,
    bestCombo: json['best_combo'] as int,
    correct: json['correct'] as int,
    wrong: json['wrong'] as int,
    missed: json['missed'] as int,
  );

  final int score;
  final int combo;
  final int bestCombo;
  final int correct;
  final int wrong;
  final int missed;

  int get total => correct + wrong + missed;
  double get accuracyPercent => total == 0 ? 0 : correct * 100 / total;

  Map<String, Object> toJson() => {
    'score': score,
    'combo': combo,
    'best_combo': bestCombo,
    'correct': correct,
    'wrong': wrong,
    'missed': missed,
  };
}

final class ShiftResult {
  const ShiftResult(this.roundId, this.stats, this.completedAt);

  factory ShiftResult.fromJson(Map<String, dynamic> json) => ShiftResult(
    json['round_id'] as String,
    ShiftStats.fromJson(json['stats'] as Map<String, dynamic>),
    DateTime.parse(json['completed_at'] as String),
  );

  final String roundId;
  final ShiftStats stats;
  final DateTime completedAt;

  Map<String, Object> toJson() => {
    'round_id': roundId,
    'stats': stats.toJson(),
    'completed_at': completedAt.toUtc().toIso8601String(),
  };
}

final class ShiftCheckpoint {
  const ShiftCheckpoint({
    required this.configVersion,
    required this.roundId,
    required this.seed,
    required this.sessionIndex,
    required this.elapsedMs,
    required this.stats,
    required this.giftIndex,
    required this.spawnedAtMs,
    required this.nextGiftAtMs,
  });

  factory ShiftCheckpoint.fromJson(Map<String, dynamic> json) =>
      ShiftCheckpoint(
        configVersion: json['config_version'] as String,
        roundId: json['round_id'] as String,
        seed: json['seed'] as int,
        sessionIndex: json['session_index'] as int,
        elapsedMs: json['elapsed_ms'] as int,
        stats: ShiftStats.fromJson(json['stats'] as Map<String, dynamic>),
        giftIndex: json['gift_index'] as int,
        spawnedAtMs: json['spawned_at_ms'] as int?,
        nextGiftAtMs: json['next_gift_at_ms'] as int?,
      );

  final String configVersion;
  final String roundId;
  final int seed;
  final int sessionIndex;
  final int elapsedMs;
  final ShiftStats stats;
  final int giftIndex;
  final int? spawnedAtMs;
  final int? nextGiftAtMs;

  Map<String, Object?> toJson() => {
    'config_version': configVersion,
    'round_id': roundId,
    'seed': seed,
    'session_index': sessionIndex,
    'elapsed_ms': elapsedMs,
    'stats': stats.toJson(),
    'gift_index': giftIndex,
    'spawned_at_ms': spawnedAtMs,
    'next_gift_at_ms': nextGiftAtMs,
  };
}

sealed class ShiftEvent {
  const ShiftEvent();
}

final class ShiftStarted extends ShiftEvent {
  const ShiftStarted(this.previousRoundId);

  final String? previousRoundId;
}

final class PhaseEntered extends ShiftEvent {
  const PhaseEntered(this.index, this.elapsedMs);

  final int index;
  final int elapsedMs;
}

final class GiftResolved extends ShiftEvent {
  const GiftResolved({
    required this.activeGift,
    required this.outcome,
    required this.elapsedMs,
    this.choice,
    this.inputMethod,
  });

  final ActiveGift activeGift;
  final GiftOutcome outcome;
  final int elapsedMs;
  final GiftClass? choice;
  final InputMethod? inputMethod;
}

final class ShiftInterrupted extends ShiftEvent {
  const ShiftInterrupted(this.reason);

  final PauseReason reason;
}

final class ShiftResumed extends ShiftEvent {
  const ShiftResumed();
}

final class ShiftCompleted extends ShiftEvent {
  const ShiftCompleted(this.result);

  final ShiftResult result;
}

final class GameEventBus {
  final _events = StreamController<ShiftEvent>.broadcast(sync: true);

  Stream<ShiftEvent> get events => _events.stream;

  void _emit(ShiftEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();
}

final class ShiftSessionController {
  ShiftSessionController({
    required this.config,
    required this.roundId,
    required this.seed,
    required this.sessionIndex,
    required this.events,
    DateTime Function()? now,
  }) : _sequence = GiftSequence(config.catalog, seed),
       _now = now ?? DateTime.now;

  factory ShiftSessionController.restore({
    required GameConfig config,
    required ShiftCheckpoint checkpoint,
    required GameEventBus events,
    DateTime Function()? now,
  }) {
    final startedAt = checkpoint.spawnedAtMs;
    final nextAt = checkpoint.nextGiftAtMs;
    final elapsed = checkpoint.elapsedMs;
    final stats = checkpoint.stats;
    if (checkpoint.configVersion != config.version ||
        elapsed < 0 ||
        elapsed >= config.durationMs ||
        checkpoint.sessionIndex < 1 ||
        checkpoint.roundId.isEmpty ||
        stats.score < 0 ||
        stats.correct < 0 ||
        stats.wrong < 0 ||
        stats.missed < 0 ||
        stats.combo < 0 ||
        stats.bestCombo < stats.combo ||
        stats.bestCombo > stats.correct ||
        ((startedAt == null) == (nextAt == null)) ||
        checkpoint.giftIndex != stats.total - (startedAt == null ? 1 : 0) ||
        checkpoint.giftIndex < 0 ||
        checkpoint.giftIndex > config.durationMs ~/ giftExitDurationMs ||
        (startedAt != null && (startedAt < 0 || startedAt > elapsed)) ||
        (nextAt != null &&
            (nextAt <= elapsed || nextAt > elapsed + giftExitDurationMs))) {
      throw const FormatException('Invalid unfinished shift.');
    }
    final shift = ShiftSessionController(
      config: config,
      roundId: checkpoint.roundId,
      seed: checkpoint.seed,
      sessionIndex: checkpoint.sessionIndex,
      events: events,
      now: now,
    );
    shift._status = ShiftStatus.paused;
    shift._pauseReason = PauseReason.restored;
    shift._elapsedMs = elapsed;
    shift._phaseIndex = config.difficulty.indexAt(elapsed);
    shift._stats = stats;
    shift._giftIndex = checkpoint.giftIndex;
    shift._nextGiftAtMs = nextAt;
    if (startedAt != null) {
      shift._spawn(startedAt, checkpoint.giftIndex);
      if (shift._activeGift!.expiresAtMs <= elapsed) {
        throw const FormatException('Invalid saved gift deadline.');
      }
    }
    return shift;
  }

  final GameConfig config;
  final String roundId;
  final int seed;
  final int sessionIndex;
  final GameEventBus events;
  final GiftSequence _sequence;
  final DateTime Function() _now;

  ShiftStatus? _status;
  PauseReason? _pauseReason;
  int _elapsedMs = 0;
  int _phaseIndex = 0;
  int _giftIndex = 0;
  int? _nextGiftAtMs;
  ActiveGift? _activeGift;
  GiftResolved? _lastResolution;
  ShiftStats _stats = const ShiftStats();
  ShiftResult? _result;

  ShiftStatus? get status => _status;
  PauseReason? get pauseReason => _pauseReason;
  int get elapsedMs => _elapsedMs;
  int get remainingMs => config.durationMs - _elapsedMs;
  int get phaseIndex => _phaseIndex;
  ActiveGift? get activeGift => _activeGift;
  GiftResolved? get lastResolution => _lastResolution;
  ShiftStats get stats => _stats;
  ShiftResult? get result => _result;

  void start({String? previousRoundId}) {
    if (_status != null) return;
    _status = ShiftStatus.playing;
    _spawn(0, 0);
    events._emit(ShiftStarted(previousRoundId));
    events._emit(const PhaseEntered(0, 0));
  }

  void advanceTo(int elapsedMs) {
    if (_status != ShiftStatus.playing || elapsedMs <= _elapsedMs) return;
    final target = min(elapsedMs, config.durationMs);
    final phases = config.difficulty.phases;

    while (_elapsedMs < target) {
      var boundary = target;
      final nextPhase = _phaseIndex + 1;
      final phaseAt = nextPhase < phases.length
          ? phases[nextPhase].startMs
          : config.durationMs;
      boundary = min(boundary, phaseAt);

      final expiresAt = _activeGift?.expiresAtMs;
      if (expiresAt != null) boundary = min(boundary, expiresAt);
      final spawnAt = _nextGiftAtMs;
      if (spawnAt != null) boundary = min(boundary, spawnAt);
      _elapsedMs = boundary;

      if (nextPhase < phases.length && boundary == phaseAt) {
        _phaseIndex = nextPhase;
        events._emit(PhaseEntered(nextPhase, boundary));
      }
      if (expiresAt == boundary) _resolve(GiftOutcome.missed);
      if (boundary == config.durationMs) {
        _finish();
        return;
      }
      if (spawnAt == boundary) _spawn(boundary, _giftIndex + 1);
    }
  }

  bool sort({
    required int giftIndex,
    required GiftClass choice,
    required InputMethod method,
  }) {
    final gift = _activeGift;
    if (_status != ShiftStatus.playing ||
        gift == null ||
        gift.index != giftIndex) {
      return false;
    }
    final outcome = gift.gift.classification == choice
        ? GiftOutcome.correct
        : GiftOutcome.wrong;
    _resolve(outcome, choice: choice, method: method);
    return true;
  }

  void pause(PauseReason reason) {
    if (_status != ShiftStatus.playing) return;
    _status = ShiftStatus.paused;
    _pauseReason = reason;
    events._emit(ShiftInterrupted(reason));
  }

  void resume() {
    if (_status != ShiftStatus.paused) return;
    _status = ShiftStatus.playing;
    _pauseReason = null;
    events._emit(const ShiftResumed());
  }

  ShiftCheckpoint checkpoint() {
    assert(_status == ShiftStatus.playing || _status == ShiftStatus.paused);
    return ShiftCheckpoint(
      configVersion: config.version,
      roundId: roundId,
      seed: seed,
      sessionIndex: sessionIndex,
      elapsedMs: _elapsedMs,
      stats: _stats,
      giftIndex: _giftIndex,
      spawnedAtMs: _activeGift?.spawnedAtMs,
      nextGiftAtMs: _nextGiftAtMs,
    );
  }

  void _spawn(int atMs, int index) {
    _giftIndex = index;
    final phaseIndex = config.difficulty.indexAt(atMs);
    _activeGift = ActiveGift(
      index: index,
      gift: _sequence.at(index),
      spawnedAtMs: atMs,
      phaseIndex: phaseIndex,
      deadlineMs: config.difficulty.phases[phaseIndex].deadlineMs,
    );
    _nextGiftAtMs = null;
  }

  void _resolve(GiftOutcome outcome, {GiftClass? choice, InputMethod? method}) {
    final gift = _activeGift!;
    final correct = outcome == GiftOutcome.correct;
    final combo = correct ? _stats.combo + 1 : 0;
    _stats = ShiftStats(
      score: _stats.score + (correct ? config.scoring.pointsFor(combo) : 0),
      combo: combo,
      bestCombo: max(_stats.bestCombo, combo),
      correct: _stats.correct + (correct ? 1 : 0),
      wrong: _stats.wrong + (outcome == GiftOutcome.wrong ? 1 : 0),
      missed: _stats.missed + (outcome == GiftOutcome.missed ? 1 : 0),
    );
    _activeGift = null;
    _nextGiftAtMs = _elapsedMs + giftExitDurationMs;
    final resolution = GiftResolved(
      activeGift: gift,
      outcome: outcome,
      elapsedMs: _elapsedMs,
      choice: choice,
      inputMethod: method,
    );
    _lastResolution = resolution;
    events._emit(resolution);
  }

  void _finish() {
    _activeGift = null;
    _nextGiftAtMs = null;
    _status = ShiftStatus.completed;
    final result = ShiftResult(roundId, _stats, _now());
    _result = result;
    events._emit(ShiftCompleted(result));
  }
}
