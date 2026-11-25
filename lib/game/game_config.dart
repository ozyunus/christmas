import 'dart:convert';

enum GiftClass { nice, naughty }

final class Gift {
  const Gift(this.id, this.classification, this.asset, {this.artBottom = .91});

  final String id;
  final GiftClass classification;
  final String asset;
  final double artBottom;
}

final class GiftCatalog {
  GiftCatalog(Iterable<Gift> gifts) : gifts = List.unmodifiable(gifts);

  final List<Gift> gifts;
}

final class DifficultyPhase {
  const DifficultyPhase(this.startMs, this.endMs, this.deadlineMs);

  final int startMs;
  final int endMs;
  final int deadlineMs;
}

final class DifficultyController {
  DifficultyController(Iterable<DifficultyPhase> phases)
    : phases = List.unmodifiable(phases) {
    if (this.phases.isEmpty) {
      throw const FormatException('Missing difficulty phases.');
    }
    var nextStart = 0;
    for (final phase in this.phases) {
      if (phase.startMs != nextStart ||
          phase.endMs <= phase.startMs ||
          phase.deadlineMs <= 0) {
        throw const FormatException('Invalid difficulty phases.');
      }
      nextStart = phase.endMs;
    }
  }

  final List<DifficultyPhase> phases;

  int indexAt(int elapsedMs) =>
      phases.lastIndexWhere((phase) => elapsedMs >= phase.startMs);
}

final class ComboTier {
  const ComboTier(this.from, this.to, this.multiplierScaled10);

  final int from;
  final int? to;
  final int multiplierScaled10;
}

final class ScoreCalculator {
  ScoreCalculator(this.base, Iterable<ComboTier> tiers)
    : tiers = List.unmodifiable(tiers);

  final int base;
  final List<ComboTier> tiers;

  int pointsFor(int combo) =>
      base *
      tiers.lastWhere((tier) => combo >= tier.from).multiplierScaled10 ~/
      10;
}

final class GameConfig {
  GameConfig._({
    required this.version,
    required this.mode,
    required this.durationMs,
    required this.catalog,
    required this.scoring,
    required this.difficulty,
  });

  factory GameConfig.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final entries = (json['gift_pool'] as List).cast<Map<String, dynamic>>();
    final gifts = [
      for (final entry in entries)
        Gift(
          entry['id'] as String,
          GiftClass.values.byName(entry['class'] as String),
          entry['asset'] as String,
        ),
    ];
    final tiers = [
      for (final entry
          in (json['combo_tiers'] as List).cast<Map<String, dynamic>>())
        ComboTier(
          entry['from'] as int,
          entry['to'] as int?,
          entry['multiplier_scaled10'] as int,
        ),
    ];
    final phases = [
      for (final entry
          in (json['deadline_by_elapsed_sec'] as List)
              .cast<Map<String, dynamic>>())
        DifficultyPhase(
          (entry['start'] as int) * 1000,
          (entry['end'] as int) * 1000,
          entry['gift_deadline_ms'] as int,
        ),
    ];
    final durationMs = json['round_duration_ms'] as int;
    final baseScore = json['base_correct_score'] as int;
    final inputs = json['inputs'] as Map<String, dynamic>;
    if (json['one_active_gift'] != true ||
        inputs['swipe_left'] != 'nice' ||
        inputs['swipe_right'] != 'naughty' ||
        inputs['left_button'] != 'nice' ||
        inputs['right_button'] != 'naughty' ||
        json['score_wrong'] != 0 ||
        json['score_missed'] != 0 ||
        json['special_rules_enabled'] != false ||
        json['progression_levels_enabled'] != false ||
        durationMs <= 0 ||
        baseScore <= 0 ||
        gifts.length < 2 ||
        gifts.map((gift) => gift.id).toSet().length != gifts.length ||
        gifts.map((gift) => gift.asset).toSet().length != gifts.length ||
        phases.isEmpty ||
        phases.last.endMs != durationMs ||
        tiers.isEmpty ||
        tiers.last.to != null) {
      throw const FormatException('Unsupported game configuration.');
    }

    var nextCombo = 1;
    for (final (index, tier) in tiers.indexed) {
      final end = tier.to;
      if (tier.from != nextCombo ||
          tier.multiplierScaled10 <= 0 ||
          (end == null ? index != tiers.length - 1 : end < tier.from)) {
        throw const FormatException('Invalid combo tiers.');
      }
      if (end != null) nextCombo = end + 1;
    }
    return GameConfig._(
      version: json['version'] as String,
      mode: json['mode'] as String,
      durationMs: durationMs,
      catalog: GiftCatalog(gifts),
      scoring: ScoreCalculator(baseScore, tiers),
      difficulty: DifficultyController(phases),
    );
  }

  final String version;
  final String mode;
  final int durationMs;
  final GiftCatalog catalog;
  final ScoreCalculator scoring;
  final DifficultyController difficulty;

  GameConfig forShift({
    required String id,
    required String mode,
    GiftCatalog? catalog,
    DifficultyController? difficulty,
  }) {
    final shiftDifficulty = difficulty ?? this.difficulty;
    return GameConfig._(
      version: '$version/$id',
      mode: mode,
      durationMs: shiftDifficulty.phases.last.endMs,
      catalog: catalog ?? this.catalog,
      scoring: scoring,
      difficulty: shiftDifficulty,
    );
  }
}

/// The published 48271 Park–Miller generator uses integer arithmetic and
/// produces the same sequence on each platform. Each bag contains every gift.
final class GiftSequence {
  GiftSequence(this.catalog, int seed) : _state = seed % 2147483646 + 1;

  final GiftCatalog catalog;
  final List<Gift> _gifts = [];
  int _state;

  Gift at(int index) {
    while (_gifts.length <= index) {
      final bag = catalog.gifts.toList();
      for (var i = bag.length - 1; i > 0; i--) {
        _state = (_state * 48271) % 2147483647;
        final j = _state % (i + 1);
        _swap(bag, i, j);
      }
      if (_gifts.isNotEmpty && _gifts.last == bag.first) {
        _swap(bag, 0, 1);
      }
      _gifts.addAll(bag);
    }
    return _gifts[index];
  }

  void _swap(List<Gift> gifts, int first, int second) {
    final previous = gifts[first];
    gifts[first] = gifts[second];
    gifts[second] = previous;
  }
}
