import 'dart:io';

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/platform/analytics.dart';
import 'package:santas_gift_rush/platform/local_save.dart';
import 'package:santas_gift_rush/ui/factory_scene.dart';
import 'package:santas_gift_rush/ui/gift_rush_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = GameConfig.parse(
    File('data/game_config.v1.json').readAsStringSync(),
  );
  late Images images;

  setUpAll(() async => images = await loadFactoryImages(config));
  tearDownAll(() => images.clearCache());

  Future<_Harness> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    FakeViewPadding insets = const FakeViewPadding(top: 47, bottom: 34),
    _MemorySave? initialRepository,
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
          config: config,
          factoryImages: images,
          initialSave: harness.repository.data,
          repository: harness.repository,
          analytics: harness,
          clockMs: () => harness.elapsedMs,
        ),
      ),
    );
    await tester.pump();
    return harness;
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
      await tester.tap(find.text('Start Shift'));
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
    expect(find.textContaining('Swipe left'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.tap(find.text('Start Shift'));
    await tester.pump();
    final seed = harness.repository.data.unfinishedShift!.seed;
    final sequence = GiftSequence(config.catalog, seed);
    final choice = sequence.at(0).classification;
    await tester.tap(find.byKey(ValueKey(choice.name)));
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

  testWidgets(
    'foreground waits for resume and a cold launch restores time and score',
    (tester) async {
      final harness = await mount(tester);
      await tester.tap(find.text('Start Shift'));
      await tester.pump();
      final seed = harness.repository.data.unfinishedShift!.seed;
      final choice = GiftSequence(config.catalog, seed).at(0).classification;
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
      await tester.tap(find.text('Start Shift'));
      await tester.pump();
      final first = harness.repository.data.unfinishedShift!;
      final classification = GiftSequence(
        config.catalog,
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

final class _Harness implements AnalyticsService {
  _Harness(this.repository);

  final _MemorySave repository;
  final events = <AnalyticsEvent>[];
  int elapsedMs = 0;

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}

final class _MemorySave implements LocalSaveRepository {
  LocalSave data = const LocalSave();

  @override
  Future<LocalSave> load() async => data;

  @override
  Future<void> save(LocalSave snapshot) async => data = snapshot;
}
