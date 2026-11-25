import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santas_gift_rush/game/game_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 54 standalone PNGs load from the Flutter asset bundle', () async {
    final manifest =
        jsonDecode(File('docs/asset_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final images = (manifest['assets'] as List).cast<Map<String, dynamic>>();
    final bundle = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths = bundle.listAssets();
    final expectedPaths = images.map((record) => record['path'] as String);
    expect(images, hasLength(54));
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
    expect(
      config.catalog.gifts.map((gift) => gift.asset),
      everyElement(isIn(expectedPaths)),
    );
  });
}
