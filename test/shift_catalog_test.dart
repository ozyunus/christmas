import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/game/shift_catalog.dart';
import 'package:santas_gift_rush/game/shift_session.dart';
import 'package:santas_gift_rush/platform/local_save.dart';

void main() {
  final arcade = GameConfig.parse(
    File('data/game_config.v1.json').readAsStringSync(),
  );
  final catalog = ShiftCatalog.parse(
    arcade,
    File('data/shifts.v1.json').readAsStringSync(),
  );

  test('campaign uses the defined durations, pools and unlock order', () {
    final [practice, workshop, finale] = catalog.campaign;
    expect(catalog.arcade.rules.scoring, same(arcade.scoring));
    expect(catalog.arcade.rules.difficulty, same(arcade.difficulty));
    expect(catalog.campaign.map((shift) => shift.rules.durationMs), [
      30000,
      45000,
      60000,
    ]);
    expect(catalog.campaign.map((shift) => shift.rules.catalog.gifts.length), [
      6,
      12,
      12,
    ]);
    expect(practice.rules.difficulty.phases.single.deadlineMs, 2500);
    expect(workshop.rules.difficulty.phases.last.deadlineMs, 1400);
    expect(finale.rules.difficulty, same(arcade.difficulty));
    expect(catalog.isUnlocked(practice, {}), isTrue);
    expect(catalog.isUnlocked(workshop, {}), isFalse);
    expect(catalog.isUnlocked(workshop, {practice.id}), isTrue);
    expect(catalog.isUnlocked(finale, {practice.id}), isFalse);
    expect(catalog.nextAfter(practice), same(workshop));
    expect(catalog.nextAfter(finale), isNull);
  });

  test('the expanded gift rotation contains every gift in each seeded bag', () {
    final practice = catalog.campaign.first;
    expect(
      practice.rules.catalog.gifts.map((gift) => gift.id),
      unorderedEquals([
        'teddy_bear',
        'toy_train',
        'coal',
        'dirty_sock',
        'toy_drum',
        'burnt_gingerbread',
      ]),
    );
    final core = catalog.arcade.rules.catalog;
    expect(core.gifts, hasLength(12));
    expect(
      core.gifts.where((gift) => gift.classification == GiftClass.nice),
      hasLength(6),
    );
    expect(
      core.gifts.map((gift) => gift.id),
      containsAll([
        'toy_drum',
        'toy_sailboat',
        'burnt_gingerbread',
        'broken_trumpet',
      ]),
    );
    expect(catalog.daily.rules.catalog, same(core));
    final sequence = GiftSequence(core, 76);
    final bag = List.generate(24, sequence.at);
    expect(bag.take(12), unorderedEquals(core.gifts));
    expect(bag.skip(12), unorderedEquals(core.gifts));
    expect(bag[11], isNot(bag[12]));
    expect(bag, List.generate(24, GiftSequence(core, 76).at));
  });

  test('accuracy and combo are evaluated against the full objectives', () {
    final workshop = catalog.campaign[1].goal!;
    final finale = catalog.campaign[2].goal!;
    expect(workshop.isMet(const ShiftStats(correct: 14)), isFalse);
    expect(workshop.isMet(const ShiftStats(correct: 15, missed: 5)), isTrue);
    expect(
      workshop.isMet(const ShiftStats(correct: 15, wrong: 1, missed: 5)),
      isFalse,
    );
    expect(finale.isMet(const ShiftStats(correct: 25, bestCombo: 9)), isFalse);
    expect(finale.isMet(const ShiftStats(correct: 25, bestCombo: 10)), isTrue);
  });

  test('regional previews have separate four-gift catalogs and goals', () {
    final [texas, tech, ice] = catalog.regionalPreviews;
    expect(catalog.regionalPreviews.map((shift) => shift.rules.durationMs), [
      30000,
      30000,
      30000,
    ]);
    expect(
      catalog.regionalPreviews.map((shift) => shift.rules.catalog.gifts.length),
      [4, 4, 4],
    );
    expect(
      {
        for (final gift in tech.rules.catalog.gifts)
          gift.id: gift.classification,
      },
      {
        'toy_drone': GiftClass.nice,
        'damaged_toy_drone': GiftClass.naughty,
        'handheld_console': GiftClass.nice,
        'cracked_handheld_console': GiftClass.naughty,
      },
    );
    expect(tech.goal!.isMet(const ShiftStats(correct: 12, wrong: 3)), isTrue);
    expect(tech.goal!.isMet(const ShiftStats(correct: 12, wrong: 4)), isFalse);
    expect(
      ice.goal!.isMet(const ShiftStats(correct: 10, bestCombo: 5)),
      isTrue,
    );
    expect(texas.beltSurges.stateAt(10000), BeltSurgeState.calm);
    expect(tech.beltSurges.stateAt(10000), BeltSurgeState.calm);
  });

  test(
    'ice surges accelerate continuously and shorten newly spawned deadlines',
    () {
      final ice = catalog.regionalPreviews.last;
      final surges = ice.beltSurges;
      expect(surges.stateAt(7999), BeltSurgeState.calm);
      expect(surges.stateAt(8000), BeltSurgeState.warning);
      expect(surges.stateAt(10000), BeltSurgeState.active);
      expect(surges.stateAt(14000), BeltSurgeState.calm);
      expect(surges.stateAt(20000), BeltSurgeState.warning);
      expect(surges.stateAt(22000), BeltSurgeState.active);
      expect(surges.stateAt(26000), BeltSurgeState.calm);
      expect(surges.beltTimeAt(10000), 10000);
      expect(surges.beltTimeAt(11000), 11850);
      expect(surges.beltTimeAt(14000), 17400);
      expect(surges.beltTimeAt(15000), 18400);
      expect(surges.beltTimeAt(23000), 27250);

      final events = GameEventBus();
      addTearDown(events.dispose);
      final shift = ShiftSessionController(
        config: ice.rules,
        roundId: 'great-lakes-surge',
        seed: 10,
        sessionIndex: 1,
        events: events,
      )..start();
      shift.advanceTo(10000);
      expect(shift.activeGift!.deadlineMs, 2300);
      shift.advanceTo(shift.activeGift!.expiresAtMs + giftExitDurationMs);
      expect(shift.activeGift!.deadlineMs, 1250);
    },
  );

  test(
    'daily gift sequence rolls over at midnight UTC and repeats within the day',
    () {
      final date = DateTime.utc(2026, 11, 25);
      final seed = ShiftCatalog.daySeed(date);
      final lateSeed = ShiftCatalog.daySeed(
        date.add(const Duration(hours: 23)),
      );
      expect(seed, lateSeed);
      expect(ShiftCatalog.daySeed(date.add(const Duration(days: 1))), seed + 1);
      final rules = catalog.daily.rules;
      expect(rules.durationMs, 60000);
      final first = GiftSequence(rules.catalog, seed);
      final replay = GiftSequence(rules.catalog, lateSeed);
      expect(List.generate(16, first.at), List.generate(16, replay.at));
    },
  );

  test(
    'Texas order progress counts only correctly shipped gifts and survives restore',
    () async {
      final texas = catalog.regionalPreviews.first;
      final events = GameEventBus();
      addTearDown(events.dispose);
      final shift = ShiftSessionController(
        config: texas.rules,
        roundId: 'texas-checkpoint',
        seed: 22,
        sessionIndex: 1,
        events: events,
      )..start();
      for (var index = 0; index < 8; index++) {
        final gift = shift.activeGift!;
        shift.sort(
          giftIndex: gift.index,
          choice: gift.gift.classification,
          method: InputMethod.button,
        );
        shift.advanceTo(shift.elapsedMs + giftExitDurationMs);
      }
      expect(shift.stats.shipped, {'rocking_horse': 2, 'cowboy_hat': 2});
      final saved = LocalSave.fromJson(
        LocalSave(
          bestScore: 2200,
          unfinishedShift: shift.checkpoint(),
          completedShifts: {catalog.campaign.first.id},
          dailyRecord: const DailyRecord(20500, 900),
        ).toJson(),
      );
      final resumed = ShiftSessionController.restore(
        config: catalog.byVersion[saved.unfinishedShift!.configVersion]!.rules,
        checkpoint: saved.unfinishedShift!,
        events: events,
      );
      expect(texas.goal!.isMet(resumed.stats), isTrue);
      expect(resumed.activeGift!.index, 8);
      expect(saved.completedShifts, {catalog.campaign.first.id});
      expect(saved.dailyRecord!.toJson(), {'day': 20500, 'score': 900});
    },
  );

  test(
    'a first playable save still resumes as the original Arcade shift',
    () async {
      final events = GameEventBus();
      addTearDown(events.dispose);
      final shift = ShiftSessionController(
        config: arcade,
        roundId: 'v1-round',
        seed: 10,
        sessionIndex: 2,
        events: events,
      )..start();
      shift.advanceTo(400);
      final legacy = LocalSave.fromJson({
        'schema': 1,
        'best_score': 300,
        'session_index': 2,
        'latest_result': null,
        'unfinished_shift': shift.checkpoint().toJson(),
      });
      final definition =
          catalog.byVersion[legacy.unfinishedShift!.configVersion]!;
      expect(definition.rules, same(arcade));
      final resumed = ShiftSessionController.restore(
        config: definition.rules,
        checkpoint: legacy.unfinishedShift!,
        events: events,
      );
      expect(resumed.remainingMs, 59600);
      expect(resumed.activeGift!.gift.id, shift.activeGift!.gift.id);
      expect(catalog.retryDefinitionFor(definition), same(catalog.arcade));
      expect(legacy.bestScore, 300);
      expect(legacy.completedShifts, isEmpty);
      expect(legacy.dailyRecord, isNull);
    },
  );

  test(
    'a saved practice round keeps its four gifts and advances to the new pool',
    () {
      final oldPractice =
          catalog.byVersion['${arcade.version}/packing_practice-v1']!;
      expect(oldPractice.rules.catalog.gifts.map((gift) => gift.id), [
        'teddy_bear',
        'toy_train',
        'coal',
        'dirty_sock',
      ]);
      expect(catalog.nextAfter(oldPractice), same(catalog.campaign[1]));
      expect(
        catalog.retryDefinitionFor(oldPractice),
        same(catalog.campaign.first),
      );
      final oldDaily = catalog.byVersion[catalog.legacyDailyVersion]!;
      expect(catalog.retryDefinitionFor(oldDaily), same(oldDaily));
    },
  );
}
