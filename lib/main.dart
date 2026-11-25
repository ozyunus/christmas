import 'dart:io';

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'game/game_config.dart';
import 'platform/local_save.dart';
import 'ui/factory_scene.dart';
import 'ui/gift_rush_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: gameTitle,
      locale: const Locale('en'),
      theme: factoryTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: child!,
      ),
      home: const _GameBoot(),
    ),
  );
}

class _GameBoot extends StatefulWidget {
  const _GameBoot();

  @override
  State<_GameBoot> createState() => _GameBootState();
}

typedef _BootData = ({
  GameConfig config,
  Images images,
  LocalSaveRepository repository,
  LocalSave save,
  bool loadError,
});

class _GameBootState extends State<_GameBoot> {
  late Future<_BootData> _boot = _load();

  Future<_BootData> _load() async {
    final config = GameConfig.parse(
      await rootBundle.loadString('data/game_config.v1.json'),
    );
    final storage = await getApplicationSupportDirectory();
    final repository = JsonLocalSaveRepository(
      File('${storage.path}/gift_rush_save.json'),
    );
    var save = const LocalSave();
    var loadError = false;
    try {
      save = await repository.load();
    } catch (_) {
      loadError = true;
    }
    final images = await loadFactoryImages(config);
    return (
      config: config,
      images: images,
      repository: repository,
      save: save,
      loadError: loadError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootData>(
      future: _boot,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return GiftRushApp(
            config: data.config,
            factoryImages: data.images,
            repository: data.repository,
            initialSave: data.save,
            loadError: data.loadError,
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "The game couldn't load.",
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _boot = _load()),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
