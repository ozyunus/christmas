import 'dart:async';

import 'package:flutter/services.dart';

abstract interface class HolidayAudio {
  void setMusicPlaying(bool playing);
  void setTreeSceneActive(bool active);
  void playSleighBells();
}

final class PlatformHolidayAudio implements HolidayAudio {
  const PlatformHolidayAudio();

  static const _channel = MethodChannel('santas_gift_rush/holiday_audio');

  @override
  void setMusicPlaying(bool playing) =>
      unawaited(_send('setMusicPlaying', playing));

  @override
  void setTreeSceneActive(bool active) =>
      unawaited(_send('setTreeSceneActive', active));

  @override
  void playSleighBells() => unawaited(_send('playSleighBells'));

  Future<void> _send(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Some hosts, including the Flutter test runner, have no audio bridge.
    } on PlatformException {
      // A missing or unreadable audio asset must not interrupt gameplay.
    }
  }
}
