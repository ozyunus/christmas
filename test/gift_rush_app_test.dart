import 'dart:io';

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/game/shift_catalog.dart';
import 'package:santas_gift_rush/platform/analytics.dart';
import 'package:santas_gift_rush/platform/holiday_audio.dart';
import 'package:santas_gift_rush/platform/local_save.dart';
import 'package:santas_gift_rush/ui/factory_scene.dart';
import 'package:santas_gift_rush/ui/gift_rush_app.dart';
import 'package:santas_gift_rush/ui/shift_flight_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = GameConfig.parse(
    File('data/game_config.v1.json').readAsStringSync(),
  );
  final content = ShiftCatalog.parse(
    config,
    File('data/shifts.v1.json').readAsStringSync(),
  );
  late Images images;

  setUpAll(() async => images = await loadFactoryImages(content.giftAssets));
  tearDownAll(() => images.clearCache());

  Future<_Harness> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    FakeViewPadding insets = const FakeViewPadding(top: 47, bottom: 34),
    _MemorySave? initialRepository,
    DateTime Function()? now,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = insets;
    addTearDown(tester.view.reset);
    final harness = _Harness(initialRepository ?? _MemorySave());
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryTheme(),
        home: GiftRushApp(
          content: content,
          factoryImages: images,
          initialSave: harness.repository.data,
          repository: harness.repository,
          analytics: harness,
          audio: harness,
          clockMs: () => harness.elapsedMs,
          now: now,
        ),
      ),
    );
    await tester.pump();
    return harness;
  }

  Future<void> sortCorrectly(
    WidgetTester tester,
    _Harness harness,
    ShiftDefinition definition,
    int count, {
    int stepMs = 200,
  }) async {
    final checkpoint = harness.repository.data.unfinishedShift!;
    final sequence = GiftSequence(definition.rules.catalog, checkpoint.seed);
    for (var index = 0; index < count; index++) {
      final label = sequence.at(index).classification == GiftClass.nice
          ? 'SHIP'
          : 'REJECT';
      await tester.tap(find.text(label));
      harness.elapsedMs += stepMs;
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (final size in const [
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(1024, 1366),
    Size(1024, 768),
    Size(1366, 1024),
  ]) {
    testWidgets('responsive safe areas on ${size.width} × ${size.height}', (
      tester,
    ) async {
      final landscape = size.width > size.height;
      final insets = landscape
          ? const FakeViewPadding(top: 24, bottom: 20, left: 26, right: 38)
          : const FakeViewPadding(top: 47, bottom: 34);
      await mount(tester, size: size, insets: insets);
      await tester.tap(find.text('Arcade'));
      await tester.pump();
      final nice = tester.getRect(find.byKey(const ValueKey('nice')));
      final naughty = tester.getRect(find.byKey(const ValueKey('naughty')));
      final pause = tester.getRect(find.byKey(const ValueKey('Pause')));
      final safe = Rect.fromLTRB(
        insets.left,
        insets.top,
        size.width - insets.right,
        size.height - insets.bottom,
      );
      for (final target in [nice, naughty, pause]) {
        expect(safe.contains(target.topLeft), isTrue);
        expect(target.right, lessThanOrEqualTo(safe.right));
        expect(target.bottom, lessThanOrEqualTo(safe.bottom));
        expect(target.width, greaterThanOrEqualTo(44));
        expect(target.height, greaterThanOrEqualTo(44));
      }
      expect(nice.right, lessThan(naughty.left));
      expect(nice.width, greaterThanOrEqualTo(120));
      expect(
        find.byKey(
          ValueKey(
            'assets/backgrounds/factory_${landscape ? 'ipad_landscape' : 'iphone_portrait'}.png',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('buttons and swipes share state and results offer replay', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.tap(find.text('How to Play'));
    await tester.pump();
    expect(find.textContaining('Swipe left or tap SHIP'), findsOneWidget);
    expect(find.textContaining('Swipe right or tap REJECT'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.tap(find.text('Arcade'));
    await tester.pump();
    expect(find.text('SHIP'), findsOneWidget);
    expect(find.text('REJECT'), findsOneWidget);
    final seed = harness.repository.data.unfinishedShift!.seed;
    final sequence = GiftSequence(content.arcade.rules.catalog, seed);
    final choice = sequence.at(0).classification;
    await tester.tap(find.text(choice == GiftClass.nice ? 'SHIP' : 'REJECT'));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hud-score'))).data,
      '100',
    );
    harness.elapsedMs = 230;
    await tester.pump(const Duration(milliseconds: 17));
    final next = sequence.at(1).classification;
    final drag = next == GiftClass.nice
        ? const Offset(-110, 0)
        : const Offset(110, 0);
    await tester.drag(find.byKey(const ValueKey('gift-arena')), drag);
    await tester.pump();
    expect(harness.repository.data.unfinishedShift!.stats.score, 200);
    final sorted = harness.events.where(
      (event) => event.name == AnalyticsEventName.giftSorted,
    );
    expect(sorted.map((event) => event.parameters['input_method']), [
      'button',
      'swipe',
    ]);

    harness.elapsedMs = 60000;
    await tester.pump(const Duration(milliseconds: 17));
    expect(find.text('Shift Complete'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(harness.repository.data.bestScore, 200);
    expect(harness.repository.data.latestResult!.stats.correct, 2);
    expect(harness.repository.data.unfinishedShift, isNull);
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    expect(harness.repository.data.sessionIndex, 2);
    expect(
      harness.events.any(
        (event) => event.name == AnalyticsEventName.gameReplayed,
      ),
      isTrue,
    );
    expect(find.byKey(const ValueKey('nice')), findsOneWidget);
  });

  testWidgets('a cleared campaign shift unlocks the next shift permanently', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.tap(find.text('Play Shifts'));
    await tester.pump();
    expect(find.text('Workshop Shift · Locked'), findsOneWidget);
    expect(find.text('Christmas Eve Rush · Locked'), findsOneWidget);
    await tester.tap(find.text('Packing Practice'));
    await tester.pump();
    expect(find.text('0/8 correct'), findsOneWidget);
    await sortCorrectly(tester, harness, content.campaign.first, 8);
    harness.elapsedMs = 30000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Shift Cleared'), findsOneWidget);
    expect(harness.repository.data.completedShifts, {'packing_practice'});
    await tester.tap(find.text('Next Shift'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShiftFlightTransition), findsOneWidget);
    expect(harness.bellCount, 1);
    expect(harness.repository.data.unfinishedShift, isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(195, 422));
    expect(find.byType(ShiftFlightTransition), findsOneWidget);
    expect(find.text('0:45'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    expect(harness.repository.data.unfinishedShift, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(ShiftFlightTransition), findsOneWidget);
    expect(find.text('0:45'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(ShiftFlightTransition), findsNothing);
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('0/15 correct'), findsOneWidget);
    expect(harness.bellCount, 1);

    await tester.pumpWidget(const SizedBox());
    await mount(tester, initialRepository: harness.repository);
    await tester.tap(find.text('Play Shifts'));
    await tester.pump();
    expect(find.text('Workshop Shift'), findsOneWidget);
  });

  testWidgets('music pauses with the app and remembers the saved toggle', (
    tester,
  ) async {
    final harness = await mount(tester);
    expect(harness.musicStates.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(harness.musicStates.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(harness.musicStates.last, isTrue);

    await tester.tap(find.text('Music On'));
    await tester.pump();
    expect(find.text('Music Off'), findsOneWidget);
    expect(harness.musicStates.last, isFalse);
    expect(harness.repository.data.musicEnabled, isFalse);

    await tester.pumpWidget(const SizedBox());
    final restored = await mount(tester, initialRepository: harness.repository);
    expect(find.text('Music Off'), findsOneWidget);
    expect(restored.musicStates.last, isFalse);
    await tester.tap(find.text('Music Off'));
    await tester.pump();
    expect(restored.musicStates.last, isTrue);
    expect(restored.repository.data.musicEnabled, isTrue);
  });

  testWidgets('the campaign final leads to Arcade and Daily Shift', (
    tester,
  ) async {
    final repository = _MemorySave()
      ..data = const LocalSave(
        completedShifts: {'packing_practice', 'workshop_shift'},
      );
    final harness = await mount(tester, initialRepository: repository);
    await tester.tap(find.text('Play Shifts'));
    await tester.pump();
    await tester.tap(find.text('Christmas Eve Rush'));
    await tester.pump();
    await sortCorrectly(tester, harness, content.campaign.last, 25);
    harness.elapsedMs = 60000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Campaign Complete'), findsOneWidget);
    expect(find.text('Play Arcade'), findsOneWidget);
    expect(find.text('Daily Shift'), findsOneWidget);
    expect(repository.data.completedShifts.length, 3);
  });

  testWidgets('Daily Shift replays the same seed and saves its own score', (
    tester,
  ) async {
    final today = DateTime.utc(2026, 11, 25, 15);
    final previousRotationRecord = _MemorySave()
      ..data = LocalSave(
        dailyRecord: DailyRecord(ShiftCatalog.daySeed(today), 900),
      );
    final harness = await mount(
      tester,
      initialRepository: previousRotationRecord,
      now: () => today,
    );
    expect(find.text('Daily Best  900'), findsNothing);
    await tester.tap(find.text('Daily Shift'));
    await tester.pump();
    final seed = harness.repository.data.unfinishedShift!.seed;
    expect(seed, ShiftCatalog.daySeed(today));
    await sortCorrectly(tester, harness, content.daily, 1);
    harness.elapsedMs = 60000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(harness.repository.data.bestScore, 0);
    expect(harness.repository.data.dailyRecord?.score, 100);
    expect(
      harness.repository.data.dailyRecord?.rulesVersion,
      content.daily.rules.version,
    );
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    expect(harness.repository.data.unfinishedShift!.seed, seed);
  });

  testWidgets('Texas preview tracks its two orders and shows the result', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.tap(find.text("Santa's Road Trip"));
    await tester.pump();
    expect(find.text('Texas Toy Roundup'), findsOneWidget);
    expect(find.text('Silicon Valley Workshop'), findsOneWidget);
    expect(find.text('Great Lakes Ice Run'), findsOneWidget);
    await tester.tap(find.text('Texas Toy Roundup'));
    await tester.pump();
    await tester.tap(find.text('Play Preview'));
    await tester.pump();
    expect(find.text('Rocking horse 0/2'), findsOneWidget);
    expect(find.text('Cowboy hat 0/2'), findsOneWidget);
    await sortCorrectly(tester, harness, content.regionalPreviews.first, 8);
    expect(find.text('Rocking horse 2/2'), findsOneWidget);
    expect(find.text('Cowboy hat 2/2'), findsOneWidget);
    harness.elapsedMs = 30000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Order Complete'), findsOneWidget);
    expect(harness.repository.data.bestScore, 0);
  });

  testWidgets('Silicon Valley previews and clears its quality-control goal', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.tap(find.text("Santa's Road Trip"));
    await tester.pump();
    await tester.tap(find.text('Silicon Valley Workshop'));
    await tester.pump();
    expect(find.text('12 correct'), findsOneWidget);
    expect(find.text('80% accuracy'), findsOneWidget);
    await tester.tap(find.text('Play Preview'));
    await tester.pump();
    final tech = content.regionalPreviews[1];
    expect(
      harness.repository.data.unfinishedShift!.configVersion,
      tech.rules.version,
    );
    await sortCorrectly(tester, harness, tech, 16, stepMs: 1700);
    harness.elapsedMs = 30000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Shift Cleared'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
  });

  testWidgets('Great Lakes signals both ice surges on the gameplay HUD', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.tap(find.text("Santa's Road Trip"));
    await tester.pump();
    await tester.tap(find.text('Great Lakes Ice Run'));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Silicon Valley Workshop'), findsOneWidget);
    await tester.tap(find.text('Great Lakes Ice Run'));
    await tester.pump();
    await tester.tap(find.text('Play Preview'));
    await tester.pump();
    final warning = find.textContaining('Ice warning');
    final surge = find.textContaining('Ice surge');
    for (final (elapsed, isWarning, isSurge) in [
      (7999, false, false),
      (8000, true, false),
      (10000, false, true),
      (14000, false, false),
      (20000, true, false),
      (22000, false, true),
      (26000, false, false),
    ]) {
      harness.elapsedMs = elapsed;
      await tester.pump(const Duration(milliseconds: 16));
      expect(warning, isWarning ? findsOneWidget : findsNothing);
      expect(surge, isSurge ? findsOneWidget : findsNothing);
    }
  });

  testWidgets(
    'foreground waits for resume and a cold launch restores time and score',
    (tester) async {
      final harness = await mount(tester);
      await tester.tap(find.text('Arcade'));
      await tester.pump();
      final seed = harness.repository.data.unfinishedShift!.seed;
      final choice = GiftSequence(
        content.arcade.rules.catalog,
        seed,
      ).at(0).classification;
      await tester.tap(find.byKey(ValueKey(choice.name)));
      await tester.pump();

      harness.elapsedMs = 1570;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Shift Paused'), findsOneWidget);
      final interrupted = harness.repository.data.unfinishedShift!;
      expect(interrupted.elapsedMs, 1570);
      expect(interrupted.stats.score, 100);
      harness.elapsedMs = 69000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Shift Paused'), findsOneWidget);
      expect(harness.repository.data.unfinishedShift!.elapsedMs, 1570);
      expect(
        harness.events
            .where((event) => event.name == AnalyticsEventName.gameInterrupted)
            .length,
        1,
      );

      await tester.pumpWidget(const SizedBox());
      final restored = await mount(
        tester,
        initialRepository: harness.repository,
      );
      expect(find.text('Resume Shift'), findsOneWidget);
      await tester.tap(find.text('Resume Shift'));
      await tester.pump();
      expect(restored.repository.data.unfinishedShift!.stats.score, 100);
      expect(find.text('Shift Paused'), findsNothing);
      restored.elapsedMs = 430;
      await tester.pump(const Duration(milliseconds: 17));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('hud-timer'))).data,
        '0:58',
      );
    },
  );

  testWidgets(
    'a held decision cannot score a gift created after pointer down',
    (tester) async {
      final harness = await mount(tester);
      await tester.tap(find.text('Arcade'));
      await tester.pump();
      final first = harness.repository.data.unfinishedShift!;
      final classification = GiftSequence(
        content.arcade.rules.catalog,
        first.seed,
      ).at(0).classification;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(classification.name))),
      );
      await tester.pump(const Duration(milliseconds: 120));
      harness.elapsedMs = 2300;
      await tester.pump(const Duration(milliseconds: 17));
      await gesture.up();
      await tester.pump();
      final current = harness.repository.data.unfinishedShift!;
      expect(current.stats.missed, 1);
      expect(current.stats.score, 0);
      expect(current.stats.total, 1);
    },
  );
}

final class _Harness implements AnalyticsService, HolidayAudio {
  _Harness(this.repository);

  final _MemorySave repository;
  final events = <AnalyticsEvent>[];
  final musicStates = <bool>[];
  int bellCount = 0;
  int elapsedMs = 0;

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);

  @override
  void setMusicPlaying(bool playing) => musicStates.add(playing);

  @override
  void playSleighBells() => bellCount++;
}

final class _MemorySave implements LocalSaveRepository {
  LocalSave data = const LocalSave();

  @override
  Future<LocalSave> load() async => data;

  @override
  Future<void> save(LocalSave snapshot) async => data = snapshot;
}
