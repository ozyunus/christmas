import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/game/shift_session.dart';
import 'package:santas_gift_rush/platform/analytics.dart';
import 'package:santas_gift_rush/platform/local_save.dart';

void main() {
  final config = GameConfig.parse(
    File('data/game_config.v1.json').readAsStringSync(),
  );
  late GameEventBus events;

  setUp(() => events = GameEventBus());
  tearDown(() => events.dispose());

  ShiftSessionController newShift() => ShiftSessionController(
    config: config,
    roundId: 'local-round',
    seed: 45,
    sessionIndex: 3,
    events: events,
  );

  test('all event wire names match the versioned schema', () {
    final schema =
        jsonDecode(
              File('data/analytics_event_names.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      AnalyticsEventName.values.map((event) => event.wireName),
      schema['event_names'],
    );
  });

  test(
    'replay, choices, interruptions, misses and results emit typed payloads',
    () async {
      final analytics = _RecordingAnalytics();
      final telemetry = ShiftTelemetry(analytics);
      final shift = newShift();
      final subscription = events.events.listen(
        (event) => telemetry.record(shift, event),
      );
      addTearDown(subscription.cancel);

      shift.start(previousRoundId: 'previous');
      shift.advanceTo(100);
      final gift = shift.activeGift!;
      final chosenClass = GiftClass.values[1 - gift.gift.classification.index];
      shift.sort(
        giftIndex: gift.index,
        choice: chosenClass,
        method: InputMethod.swipe,
      );
      shift.pause(PauseReason.background);
      shift.resume();
      shift.advanceTo(60000);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.events.take(6).map((event) => event.name), [
        AnalyticsEventName.gameReplayed,
        AnalyticsEventName.gameStarted,
        AnalyticsEventName.difficultyPhaseEntered,
        AnalyticsEventName.giftSorted,
        AnalyticsEventName.gameInterrupted,
        AnalyticsEventName.gameResumed,
      ]);
      expect(analytics.events[3].parameters, {
        'round_id': 'local-round',
        'gift_id': gift.gift.id,
        'classification': chosenClass.name,
        'correct': 0,
        'phase_index': 0,
        'response_ms': 100,
        'input_method': 'swipe',
      });
      expect(analytics.events[6].name, AnalyticsEventName.giftMissed);
      expect(analytics.events.last.name, AnalyticsEventName.gameCompleted);
      expect(analytics.events.last.parameters['duration_ms'], 60000);
      expect(analytics.events.last.parameters['wrong_count'], 1);
    },
  );

  test(
    'an offline analytics service cannot interfere with game completion',
    () async {
      final telemetry = ShiftTelemetry(
        FirebaseAnalyticsAdapter((name, parameters) async {
          throw StateError('Offline');
        }),
      );
      final shift = newShift();
      final subscription = events.events.listen(
        (event) => telemetry.record(shift, event),
      );
      addTearDown(subscription.cancel);
      shift.start();
      shift.advanceTo(60000);
      await Future<void>.delayed(Duration.zero);
      expect(shift.status, ShiftStatus.completed);
    },
  );

  test(
    'local save writes are ordered and a new repository can resume the shift',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'santa-save-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/save.json');
      final repository = JsonLocalSaveRepository(file);
      expect((await repository.load()).unfinishedShift, isNull);
      final shift = newShift()..start();
      final gift = shift.activeGift!;
      shift.sort(
        giftIndex: gift.index,
        choice: gift.gift.classification,
        method: InputMethod.button,
      );
      shift.advanceTo(575);
      final checkpoint = shift.checkpoint();
      await Future.wait([
        repository.save(const LocalSave(bestScore: 200)),
        repository.save(
          LocalSave(
            bestScore: 500,
            sessionIndex: 3,
            unfinishedShift: checkpoint,
          ),
        ),
      ]);
      final saved = await JsonLocalSaveRepository(file).load();
      expect(saved.bestScore, 500);
      expect(saved.sessionIndex, 3);
      expect(saved.unfinishedShift!.elapsedMs, 575);
      expect(saved.unfinishedShift!.stats.score, 100);
      final restored = ShiftSessionController.restore(
        config: config,
        checkpoint: saved.unfinishedShift!,
        events: events,
      );
      expect(restored.activeGift!.index, 1);
      expect(restored.status, ShiftStatus.paused);
    },
  );
}

final class _RecordingAnalytics implements AnalyticsService {
  final events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}
