import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/game/shift_session.dart';

void main() {
  final source = File('data/game_config.v1.json').readAsStringSync();
  final config = GameConfig.parse(source);
  late GameEventBus bus;

  setUp(() => bus = GameEventBus());
  tearDown(() => bus.dispose());

  ShiftSessionController start([GameConfig? override]) =>
      ShiftSessionController(
        config: override ?? config,
        roundId: 'test-round',
        seed: 76,
        sessionIndex: 1,
        events: bus,
        now: () => DateTime.utc(2026, 11, 25),
      )..start();

  GameConfig shortRound(int deadlineMs) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    json['round_duration_ms'] = 1000;
    json['deadline_by_elapsed_sec'] = [
      {'start': 0, 'end': 1, 'gift_deadline_ms': deadlineMs},
    ];
    return GameConfig.parse(jsonEncode(json));
  }

  bool tap(ShiftSessionController shift, {bool correct = true}) {
    final gift = shift.activeGift!;
    final classification = gift.gift.classification;
    return shift.sort(
      giftIndex: gift.index,
      choice: correct
          ? classification
          : GiftClass.values[1 - classification.index],
      method: InputMethod.button,
    );
  }

  test('configuration uses the specified eight classifications', () {
    expect(config.durationMs, 60000);
    expect(
      {
        for (final gift in config.catalog.gifts)
          gift.id: gift.classification.name,
      },
      {
        'teddy_bear': 'nice',
        'toy_train': 'nice',
        'candy_cane': 'nice',
        'toy_robot': 'nice',
        'coal': 'naughty',
        'dirty_sock': 'naughty',
        'prank_spider': 'naughty',
        'broken_ornament': 'naughty',
      },
    );
  });

  test('same seed has a stable sequence and each bag contains every gift', () {
    final sequence = GiftSequence(config.catalog, 76);
    final another = GiftSequence(config.catalog, 76);
    final gifts = List.generate(48, sequence.at);
    expect(gifts, List.generate(48, another.at));
    expect(gifts.take(8).map((gift) => gift.id), [
      'prank_spider',
      'teddy_bear',
      'dirty_sock',
      'coal',
      'broken_ornament',
      'candy_cane',
      'toy_train',
      'toy_robot',
    ]);
    expect(gifts, isNot(List.generate(48, GiftSequence(config.catalog, 7).at)));
    for (var start = 0; start < gifts.length; start += 8) {
      expect(gifts.skip(start).take(8), unorderedEquals(config.catalog.gifts));
    }
    for (var index = 1; index < gifts.length; index++) {
      expect(gifts[index], isNot(gifts[index - 1]));
    }
  });

  test('combo boundaries use the newly incremented combo', () {
    final shift = start();
    final expected = [100, 120, 150, 180, 200];
    final bestCombos = [1, 4, 5, 9, 10, 14, 15, 19, 20, 21];
    var previousScore = 0;
    for (var combo = 1; combo <= 21; combo++) {
      expect(tap(shift), isTrue);
      final tier = config.scoring.tiers.lastIndexWhere(
        (tier) => combo >= tier.from,
      );
      expect(shift.stats.score - previousScore, expected[tier]);
      if (bestCombos.contains(combo)) {
        expect(shift.stats.bestCombo, combo);
      }
      previousScore = shift.stats.score;
      shift.advanceTo(shift.elapsedMs + giftExitDurationMs);
    }
  });

  test('wrong and timed-out gifts reset combo and keep earlier score', () {
    final shift = start();
    tap(shift);
    shift.advanceTo(giftExitDurationMs);
    tap(shift, correct: false);
    expect(shift.stats.combo, 0);
    expect(shift.stats.wrong, 1);
    shift.advanceTo(giftExitDurationMs * 2);
    tap(shift);
    shift.advanceTo(giftExitDurationMs * 3);
    final deadline = shift.activeGift!.expiresAtMs;
    shift.advanceTo(deadline - 1);
    expect(shift.stats.missed, 0);
    shift.advanceTo(deadline);
    expect(shift.stats.missed, 1);
    expect(shift.stats.combo, 0);
    expect(shift.stats.score, 200);
    expect(shift.stats.accuracyPercent, 50);
  });

  test('only one active gift and stale inputs cannot hit the next gift', () {
    final shift = start();
    final first = shift.activeGift!;
    expect(tap(shift), isTrue);
    for (final time in [0, 179, 180]) {
      shift.advanceTo(time);
      expect(
        shift.sort(
          giftIndex: first.index,
          choice: first.gift.classification,
          method: InputMethod.swipe,
        ),
        isFalse,
      );
    }
    expect(shift.activeGift!.index, first.index + 1);
    expect(shift.stats.score, 100);
  });

  test(
    'phase starts exactly on each threshold and deadlines are fixed at spawn',
    () {
      final shift = start();
      final phases = <(int, int)>[];
      final subscription = bus.events.listen((event) {
        if (event is PhaseEntered) phases.add((event.index, event.elapsedMs));
      });
      addTearDown(subscription.cancel);
      final deadlines = [2000, 1650, 1400, 1200, 1100, 1000];
      for (var index = 1; index <= 5; index++) {
        final threshold = index * 10000;
        shift.advanceTo(threshold - 1);
        expect(shift.phaseIndex, index - 1);
        final oldGift = shift.activeGift;
        shift.advanceTo(threshold);
        expect(shift.phaseIndex, index);
        expect(config.difficulty.phases[index].deadlineMs, deadlines[index]);
        if (oldGift != null && oldGift.expiresAtMs > threshold) {
          expect(shift.activeGift, same(oldGift));
          expect(oldGift.deadlineMs, deadlines[index - 1]);
        }
      }
      expect(phases, [
        (1, 10000),
        (2, 20000),
        (3, 30000),
        (4, 40000),
        (5, 50000),
      ]);
    },
  );

  test(
    'pause freezes both clocks and explicit resume continues elapsed time',
    () {
      final shift = start()..advanceTo(750);
      final gift = shift.activeGift;
      shift.pause(PauseReason.background);
      shift.advanceTo(60000);
      expect(shift.elapsedMs, 750);
      expect(shift.activeGift, same(gift));
      expect(tap(shift), isFalse);
      shift.resume();
      shift.advanceTo(2000);
      expect(shift.stats.missed, 1);
    },
  );

  test('the 60-second limit finalizes the shift only once', () {
    final shift = start();
    var completions = 0;
    final subscription = bus.events.listen((event) {
      if (event is ShiftCompleted) completions++;
    });
    addTearDown(subscription.cancel);
    shift.advanceTo(59999);
    expect(shift.result, isNull);
    shift.advanceTo(60000);
    shift.advanceTo(67000);
    expect(shift.status, ShiftStatus.completed);
    expect(shift.elapsedMs, 60000);
    expect(shift.activeGift, isNull);
    expect(shift.result!.completedAt, DateTime.utc(2026, 11, 25));
    expect(completions, 1);
  });

  for (final (deadline, missed) in [(1000, 1), (1200, 0)]) {
    test('round end counts only expired gifts (deadline $deadline ms)', () {
      final shift = start(shortRound(deadline));
      final index = shift.activeGift!.index;
      shift.advanceTo(1000);
      expect(shift.stats.missed, missed);
      expect(shift.result!.stats.total, missed);
      expect(
        shift.sort(
          giftIndex: index,
          choice: GiftClass.nice,
          method: InputMethod.swipe,
        ),
        isFalse,
      );
    });
  }

  test(
    'restore preserves active gift, remaining time, score and pause state',
    () {
      final original = start();
      tap(original);
      original.advanceTo(915);
      final restored = ShiftSessionController.restore(
        config: config,
        checkpoint: original.checkpoint(),
        events: bus,
      );
      expect(restored.status, ShiftStatus.paused);
      expect(restored.pauseReason, PauseReason.restored);
      expect(restored.elapsedMs, 915);
      expect(restored.stats.score, 100);
      expect(restored.stats.combo, 1);
      expect(restored.activeGift!.gift.id, original.activeGift!.gift.id);
      expect(
        restored.activeGift!.expiresAtMs,
        original.activeGift!.expiresAtMs,
      );
      restored.resume();
      expect(tap(restored), isTrue);
      expect(restored.stats.score, 200);
    },
  );

  test('restore during an exit transition does not resurrect that gift', () {
    final original = start();
    tap(original);
    original.advanceTo(100);
    final restored = ShiftSessionController.restore(
      config: config,
      checkpoint: original.checkpoint(),
      events: bus,
    );
    expect(restored.activeGift, isNull);
    restored.resume();
    restored.advanceTo(giftExitDurationMs);
    expect(restored.activeGift!.index, 1);
    expect(restored.stats.correct, 1);
  });
}
