import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../game/game_config.dart';
import '../game/shift_catalog.dart';
import '../game/shift_session.dart';
import 'game_layout.dart';
import 'shift_flight_transition.dart';

const _belt = 'assets/factory/conveyor/conveyor_belt_tile.png';
const _frame = 'assets/factory/conveyor/conveyor_frame.png';
const _sparkle = 'assets/ui/effects/sparkle_gold.png';
const _snowflake = 'assets/ui/effects/snowflake_white.png';
const _elfFolder = 'assets/characters/elf_';

Future<Images> loadFactoryImages(Iterable<String> giftAssets) async {
  final images = Images(prefix: '');
  try {
    await images.loadAll([
      _belt,
      _frame,
      _sparkle,
      _snowflake,
      santaSleighAsset,
      for (final pose in ['idle', 'happy', 'sad', 'celebrate'])
        '$_elfFolder$pose.png',
      ...giftAssets,
    ]);
  } catch (_) {
    images.clearCache();
    rethrow;
  }
  return images;
}

final class FactoryScene extends FlameGame {
  FactoryScene({
    required this.shift,
    required this.beltSurges,
    required Images factoryImages,
  }) {
    images = factoryImages;
  }

  final ShiftSessionController shift;
  final BeltSurges beltSurges;
  ResponsiveGameLayout? layout;
  bool reduceMotion = false;

  final _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final gameLayout = layout;
    if (gameLayout == null) return;
    final arena = gameLayout.arena;
    final giftSize = gameLayout.giftSize;
    final giftCenter = Offset(
      arena.center.dx,
      gameLayout.beltTop - giftSize * .41,
    );

    final halo = Rect.fromCenter(
      center: giftCenter,
      width: giftSize * 2.12,
      height: giftSize * 1.67,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xBC172322), Color(0x00172322)],
        ).createShader(halo),
    );
    _drawConveyor(canvas, gameLayout);

    final recent = shift.lastResolution;
    final sinceResolution = recent == null
        ? double.infinity
        : (shift.elapsedMs - recent.elapsedMs).toDouble();
    final activeGift = shift.activeGift;
    if (activeGift != null) {
      final age = shift.elapsedMs - activeGift.spawnedAtMs;
      final arrival = reduceMotion ? 0.0 : 1 - min(age / 120, 1.0);
      _drawSprite(
        canvas,
        activeGift.gift.asset,
        giftCenter.translate(
          -giftSize * .23 * arrival,
          giftSize * (.91 - activeGift.gift.artBottom),
        ),
        width: giftSize,
      );
    } else if (recent != null &&
        sinceResolution < giftExitDurationMs &&
        !reduceMotion) {
      final progress = sinceResolution / giftExitDurationMs;
      final direction = switch (recent.choice) {
        GiftClass.nice => -1,
        GiftClass.naughty => 1,
        null => 0,
      };
      _drawSprite(
        canvas,
        recent.activeGift.gift.asset,
        giftCenter.translate(
          arena.width * .34 * progress * direction,
          giftSize * (.91 - recent.activeGift.gift.artBottom) +
              (direction == 0
                  ? giftSize * .36 * progress
                  : -giftSize * .24 * progress),
        ),
        width: giftSize * (1 - .28 * progress),
        opacity: 1 - progress,
      );
    }

    final pose = switch (recent?.outcome) {
      GiftOutcome.correct when sinceResolution < 350 =>
        shift.stats.combo % 5 == 0 ? 'celebrate' : 'happy',
      GiftOutcome.wrong ||
      GiftOutcome.missed when sinceResolution < 350 => 'sad',
      _ => 'idle',
    };
    final elfWidth = min(giftSize * .79, arena.width * .26);
    _drawSprite(
      canvas,
      '$_elfFolder$pose.png',
      Offset(
        arena.left + arena.width * .83,
        gameLayout.beltTop - elfWidth * .50,
      ),
      width: elfWidth,
    );

    if (recent != null && sinceResolution < 320 && !reduceMotion) {
      final progress = sinceResolution / 320;
      _drawSprite(
        canvas,
        recent.outcome == GiftOutcome.correct ? _sparkle : _snowflake,
        giftCenter.translate(-giftSize * .46, giftSize * (-.3 - progress * .2)),
        width: giftSize * (.18 + .16 * progress),
        opacity: 1 - progress,
      );
    }
  }

  void _drawConveyor(Canvas canvas, ResponsiveGameLayout gameLayout) {
    final width = gameLayout.beltWidth;
    final height = width * 340 / 1280;
    final left = gameLayout.arena.center.dx - width / 2;
    final top = gameLayout.beltTop - height * 66 / 340;
    final opening = Rect.fromLTWH(
      left + width * .045,
      top + height * 98 / 340,
      width * .91,
      height * 121 / 340,
    );
    final tileWidth = opening.height * 2;
    final offset = reduceMotion
        ? 0.0
        : (beltSurges.beltTimeAt(shift.elapsedMs) * .14) % tileWidth;

    canvas.save();
    canvas.clipRect(opening);
    canvas.drawRect(opening, Paint()..color = const Color(0xFF24373E));
    for (var x = opening.left - offset; x < opening.right; x += tileWidth) {
      _drawImage(
        canvas,
        _belt,
        Rect.fromLTWH(x, opening.top, tileWidth, opening.height),
        1,
      );
    }
    if (beltSurges.stateAt(shift.elapsedMs) == BeltSurgeState.active) {
      canvas.drawRect(opening, Paint()..color = const Color(0x447FD4F6));
    }
    canvas.restore();
    _drawImage(canvas, _frame, Rect.fromLTWH(left, top, width, height), 1);
  }

  void _drawSprite(
    Canvas canvas,
    String path,
    Offset center, {
    required double width,
    double opacity = 1,
  }) {
    final image = images.fromCache(path);
    _drawImage(
      canvas,
      path,
      Rect.fromCenter(
        center: center,
        width: width,
        height: width * image.height / image.width,
      ),
      opacity,
    );
  }

  void _drawImage(
    Canvas canvas,
    String path,
    Rect destination,
    double opacity,
  ) {
    final image = images.fromCache(path);
    _spritePaint.color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      _spritePaint,
    );
  }
}
