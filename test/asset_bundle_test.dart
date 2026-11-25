import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';
import 'package:santas_gift_rush/game/shift_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all documented PNGs load from the Flutter asset bundle', () async {
    final manifest =
        jsonDecode(File('docs/asset_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final images = (manifest['assets'] as List).cast<Map<String, dynamic>>();
    final bundle = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths = bundle.listAssets();
    final expectedPaths = images.map((record) => record['path'] as String);
    expect(images, hasLength(manifest['count'] as int));
    expect(
      assetPaths.where((name) => name.endsWith('.png')),
      unorderedEquals(expectedPaths),
    );
    expect(
      assetPaths.any((name) => name.startsWith('docs/previews/')),
      isFalse,
    );

    for (final record in images) {
      final path = record['path'] as String;
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, record['w'], reason: path);
          expect(frame.image.height, record['h'], reason: path);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }

    final config = GameConfig.parse(
      await rootBundle.loadString('data/game_config.v1.json'),
    );
    final shifts = ShiftCatalog.parse(
      config,
      await rootBundle.loadString('data/shifts.v1.json'),
    );
    expect(shifts.giftAssets, everyElement(isIn(expectedPaths)));
  });

  test('the three soundtrack tracks and the sleigh cue are bundled', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    const files = [
      'assets/audio/workshop_lights.mp3',
      'assets/audio/sleigh_route.mp3',
      'assets/audio/snowfall_at_the_pole.mp3',
      'assets/audio/sleigh_bells.mp3',
    ];
    expect(
      manifest.listAssets().where((name) => name.endsWith('.mp3')),
      unorderedEquals(files),
    );
    for (final file in files) {
      final bytes = await rootBundle.load(file);
      expect(bytes.lengthInBytes, greaterThan(1024), reason: file);
    }
  });
}
