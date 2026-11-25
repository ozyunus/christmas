import 'dart:convert';
import 'dart:io';

import '../game/shift_session.dart';

final class LocalSave {
  const LocalSave({
    this.bestScore = 0,
    this.sessionIndex = 0,
    this.latestResult,
    this.unfinishedShift,
  });

  factory LocalSave.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported local save version.');
    }
    final result = json['latest_result'] as Map<String, dynamic>?;
    final checkpoint = json['unfinished_shift'] as Map<String, dynamic>?;
    return LocalSave(
      bestScore: json['best_score'] as int,
      sessionIndex: json['session_index'] as int,
      latestResult: result == null ? null : ShiftResult.fromJson(result),
      unfinishedShift: checkpoint == null
          ? null
          : ShiftCheckpoint.fromJson(checkpoint),
    );
  }

  final int bestScore;
  final int sessionIndex;
  final ShiftResult? latestResult;
  final ShiftCheckpoint? unfinishedShift;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'best_score': bestScore,
    'session_index': sessionIndex,
    'latest_result': latestResult?.toJson(),
    'unfinished_shift': unfinishedShift?.toJson(),
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
