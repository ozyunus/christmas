import 'dart:convert';
import 'dart:io';

import '../game/shift_session.dart';

final class DailyRecord {
  const DailyRecord(this.day, this.score, {this.rulesVersion});

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    json['day'] as int,
    json['score'] as int,
    rulesVersion: json['rules_version'] as String?,
  );

  final int day;
  final int score;
  final String? rulesVersion;

  Map<String, Object> toJson() => {
    'day': day,
    'score': score,
    'rules_version': ?rulesVersion,
  };
}

final class LocalSave {
  const LocalSave({
    this.bestScore = 0,
    this.sessionIndex = 0,
    this.latestResult,
    this.unfinishedShift,
    this.completedShifts = const {},
    this.deliveredGifts = const {},
    this.dailyRecord,
    this.musicEnabled = true,
    this.onboardingSeen = false,
  });

  factory LocalSave.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported local save version.');
    }
    final result = json['latest_result'] as Map<String, dynamic>?;
    final checkpoint = json['unfinished_shift'] as Map<String, dynamic>?;
    final daily = json['daily_record'] as Map<String, dynamic>?;
    return LocalSave(
      bestScore: json['best_score'] as int,
      sessionIndex: json['session_index'] as int,
      latestResult: result == null ? null : ShiftResult.fromJson(result),
      unfinishedShift: checkpoint == null
          ? null
          : ShiftCheckpoint.fromJson(checkpoint),
      completedShifts: Set.unmodifiable(
        (json['completed_shifts'] as List?)?.cast<String>() ?? const <String>[],
      ),
      deliveredGifts: Set.unmodifiable(
        (json['delivered_gifts'] as List?)?.cast<String>() ?? const <String>[],
      ),
      dailyRecord: daily == null ? null : DailyRecord.fromJson(daily),
      musicEnabled: json['music_enabled'] as bool? ?? true,
      onboardingSeen: json['onboarding_seen'] as bool? ?? false,
    );
  }

  final int bestScore;
  final int sessionIndex;
  final ShiftResult? latestResult;
  final ShiftCheckpoint? unfinishedShift;
  final Set<String> completedShifts;
  final Set<String> deliveredGifts;
  final DailyRecord? dailyRecord;
  final bool musicEnabled;
  final bool onboardingSeen;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'best_score': bestScore,
    'session_index': sessionIndex,
    'latest_result': latestResult?.toJson(),
    'unfinished_shift': unfinishedShift?.toJson(),
    'completed_shifts': completedShifts.toList(),
    if (deliveredGifts.isNotEmpty) 'delivered_gifts': deliveredGifts.toList(),
    'daily_record': dailyRecord?.toJson(),
    'music_enabled': musicEnabled,
    'onboarding_seen': onboardingSeen,
  };
}

abstract interface class LocalSaveRepository {
  Future<LocalSave> load();
  Future<void> save(LocalSave data);
}

final class JsonLocalSaveRepository implements LocalSaveRepository {
  JsonLocalSaveRepository(this.file);

  final File file;
  Future<void> _pending = Future<void>.value();

  @override
  Future<LocalSave> load() async {
    await _pending;
    if (!await file.exists()) return const LocalSave();
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return LocalSave.fromJson(data);
  }

  @override
  Future<void> save(LocalSave data) {
    final encoded = jsonEncode(data.toJson());
    final write = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(encoded, flush: true);
      await temporary.rename(file.path);
    });
    // Keep later saves runnable if one write failed.
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
