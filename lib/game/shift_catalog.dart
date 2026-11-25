import 'dart:convert';

import 'game_config.dart';
import 'shift_session.dart';

enum ShiftMode { arcade, daily, campaign, regional }

enum BeltSurgeState { calm, warning, active }

final class BeltSurges {
  const BeltSurges(this.phases);

  final List<DifficultyPhase> phases;

  BeltSurgeState stateAt(int elapsedMs) {
    for (final phase in phases) {
      if (elapsedMs >= phase.startMs && elapsedMs < phase.endMs) {
        return BeltSurgeState.active;
      }
      if (elapsedMs >= phase.startMs - 2000 && elapsedMs < phase.startMs) {
        return BeltSurgeState.warning;
      }
    }
    return BeltSurgeState.calm;
  }

  double beltTimeAt(int elapsedMs) {
    var acceleratedMs = 0;
    for (final phase in phases) {
      acceleratedMs += (elapsedMs - phase.startMs).clamp(
        0,
        phase.endMs - phase.startMs,
      );
    }
    return elapsedMs + acceleratedMs * .85;
  }
}

final class ShiftGoal {
  const ShiftGoal({
    this.correct = 0,
    this.accuracyPercent = 0,
    this.combo = 0,
    this.shipped = const {},
  });

  factory ShiftGoal.fromJson(Map<String, dynamic> json, GiftCatalog catalog) {
    final correct = json['correct'] as int? ?? 0;
    final accuracy = json['accuracy_pct'] as int? ?? 0;
    final combo = json['combo'] as int? ?? 0;
    final shipped = (json['shipped'] as Map<String, dynamic>? ?? const {})
        .cast<String, int>();
    final shippable = {
      for (final gift in catalog.gifts)
        if (gift.classification == GiftClass.nice) gift.id,
    };
    if (correct < 0 ||
        accuracy < 0 ||
        accuracy > 100 ||
        combo < 0 ||
        shipped.entries.any(
          (entry) => !shippable.contains(entry.key) || entry.value <= 0,
        ) ||
        (correct == 0 && accuracy == 0 && combo == 0 && shipped.isEmpty)) {
      throw const FormatException('Invalid shift objective.');
    }
    return ShiftGoal(
      correct: correct,
      accuracyPercent: accuracy,
      combo: combo,
      shipped: Map.unmodifiable(shipped),
    );
  }

  final int correct;
  final int accuracyPercent;
  final int combo;
  final Map<String, int> shipped;

  bool isMet(ShiftStats stats) =>
      stats.correct >= correct &&
      stats.accuracyPercent >= accuracyPercent &&
      stats.bestCombo >= combo &&
      shipped.entries.every(
        (entry) => (stats.shipped[entry.key] ?? 0) >= entry.value,
      );
}

final class ShiftDefinition {
  const ShiftDefinition({
    required this.id,
    required this.title,
    required this.mode,
    required this.rules,
    this.goal,
    this.previewGuide,
    this.beltSurges = const BeltSurges([]),
  });

  final String id;
  final String title;
  final ShiftMode mode;
  final GameConfig rules;
  final ShiftGoal? goal;
  final String? previewGuide;
  final BeltSurges beltSurges;

  ShiftDefinition _withExpandedPool(GiftCatalog catalog) => ShiftDefinition(
    id: id,
    title: title,
    mode: mode,
    rules: rules.forShift(
      id: 'gift-pool-v2',
      mode: rules.mode,
      catalog: catalog,
    ),
    goal: goal,
    previewGuide: previewGuide,
    beltSurges: beltSurges,
  );
}

final class ShiftCatalog {
  ShiftCatalog._(
    this.arcade,
    this.daily,
    this.campaign,
    this.regionalPreviews,
    this.legacyDailyVersion,
    List<ShiftDefinition> legacyShifts,
  ) : byVersion = Map.unmodifiable({
        for (final shift in legacyShifts) shift.rules.version: shift,
        for (final shift in [arcade, daily, ...campaign, ...regionalPreviews])
          shift.rules.version: shift,
      });

  factory ShiftCatalog.parse(GameConfig base, String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported shift catalog version.');
    }
    final expandedGifts = [
      ...base.catalog.gifts,
      ..._readGifts(json['core_gifts'] as List),
    ];
    final allGifts = [
      ...expandedGifts,
      ..._readGifts(json['regional_gifts'] as List),
    ];
    final gifts = {for (final gift in allGifts) gift.id: gift};
    if (gifts.length != allGifts.length ||
        allGifts.map((gift) => gift.asset).toSet().length != allGifts.length) {
      throw const FormatException('Duplicate gift ID or asset.');
    }

    final identifiers = {'arcade', 'daily'};
    final campaignRecords = (json['campaign'] as List)
        .cast<Map<String, dynamic>>();
    // Saved shifts replay the exact gift catalog identified by their version.
    final legacyCampaign = [
      for (final item in campaignRecords)
        _parseShift(base, ShiftMode.campaign, item, gifts, identifiers),
    ];
    final legacyArcade = ShiftDefinition(
      id: 'arcade',
      title: 'Arcade',
      mode: ShiftMode.arcade,
      rules: base,
    );
    final legacyDaily = ShiftDefinition(
      id: 'daily',
      title: 'Daily Shift',
      mode: ShiftMode.daily,
      rules: base.forShift(id: 'daily-v1', mode: 'daily'),
    );
    final expandedCatalog = GiftCatalog(expandedGifts);
    return ShiftCatalog._(
      legacyArcade._withExpandedPool(expandedCatalog),
      legacyDaily._withExpandedPool(expandedCatalog),
      List.unmodifiable([
        for (final (index, shift) in legacyCampaign.indexed)
          shift._withExpandedPool(
            _expandCampaignPool(shift, campaignRecords[index], expandedCatalog),
          ),
      ]),
      List.unmodifiable([
        for (final item
            in (json['regional_previews'] as List).cast<Map<String, dynamic>>())
          _parseShift(base, ShiftMode.regional, item, gifts, identifiers),
      ]),
      legacyDaily.rules.version,
      [legacyArcade, legacyDaily, ...legacyCampaign],
    );
  }

  final ShiftDefinition arcade;
  final ShiftDefinition daily;
  final List<ShiftDefinition> campaign;
  final List<ShiftDefinition> regionalPreviews;
  final String legacyDailyVersion;
  final Map<String, ShiftDefinition> byVersion;

  Set<String> get giftAssets => {
    for (final shift in byVersion.values)
      for (final gift in shift.rules.catalog.gifts) gift.asset,
  };

  ShiftDefinition? nextAfter(ShiftDefinition shift) {
    final index = campaign.indexWhere((candidate) => candidate.id == shift.id);
    return index >= 0 && index + 1 < campaign.length
        ? campaign[index + 1]
        : null;
  }

  bool isUnlocked(ShiftDefinition shift, Set<String> completed) {
    final index = campaign.indexWhere((candidate) => candidate.id == shift.id);
    return index <= 0 || completed.contains(campaign[index - 1].id);
  }

  ShiftDefinition retryDefinitionFor(ShiftDefinition shift) =>
      switch (shift.mode) {
        ShiftMode.arcade => arcade,
        ShiftMode.campaign => campaign.firstWhere(
          (candidate) => candidate.id == shift.id,
        ),
        ShiftMode.daily || ShiftMode.regional => shift,
      };

  static int daySeed(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static Iterable<Gift> _readGifts(List records) sync* {
    for (final record in records.cast<Map<String, dynamic>>()) {
      final gift = Gift(
        record['id'] as String,
        GiftClass.values.byName(record['class'] as String),
        record['asset'] as String,
        artBottom: (record['art_bottom'] as num?)?.toDouble() ?? .91,
      );
      if (gift.id.isEmpty ||
          !gift.artBottom.isFinite ||
          gift.artBottom <= .5 ||
          gift.artBottom > 1) {
        throw const FormatException('Invalid gift.');
      }
      yield gift;
    }
  }

  static GiftCatalog _expandCampaignPool(
    ShiftDefinition shift,
    Map<String, dynamic> record,
    GiftCatalog expandedCatalog,
  ) {
    final extraIds = (record['extra_gift_ids'] as List?)?.cast<String>();
    if (record['gift_ids'] == null) return expandedCatalog;
    final additions = expandedCatalog.gifts.where(
      (gift) => extraIds?.contains(gift.id) ?? false,
    );
    final pool = [...shift.rules.catalog.gifts, ...additions];
    if (pool.toSet().length != pool.length ||
        additions.length != (extraIds?.length ?? 0)) {
      throw const FormatException('Invalid campaign gift expansion.');
    }
    return GiftCatalog(pool);
  }

  static ShiftDefinition _parseShift(
    GameConfig base,
    ShiftMode mode,
    Map<String, dynamic> json,
    Map<String, Gift> gifts,
    Set<String> identifiers,
  ) {
    final id = json['id'] as String;
    final title = json['title'] as String;
    if (id.isEmpty || title.isEmpty || !identifiers.add(id)) {
      throw const FormatException('Invalid or duplicate shift.');
    }

    final giftIds = (json['gift_ids'] as List?)?.cast<String>();
    final pool = giftIds == null
        ? base.catalog
        : GiftCatalog(
            giftIds.map(
              (id) => gifts[id] ?? (throw FormatException('Unknown gift: $id')),
            ),
          );
    if (pool.gifts.length < 2 ||
        pool.gifts.toSet().length != pool.gifts.length) {
      throw const FormatException('Invalid shift gift pool.');
    }

    final phaseRecords = (json['phases'] as List?)
        ?.cast<Map<String, dynamic>>();
    final phases = <DifficultyPhase>[];
    final surges = <DifficultyPhase>[];
    var startMs = 0;
    for (final phase in phaseRecords ?? const []) {
      final endMs = (phase['end_sec'] as int) * 1000;
      final difficulty = DifficultyPhase(
        startMs,
        endMs,
        phase['deadline_ms'] as int,
      );
      phases.add(difficulty);
      if (phase['surge'] == true) surges.add(difficulty);
      startMs = endMs;
    }
    final rules = base.forShift(
      id: '$id-v1',
      mode: mode.name,
      catalog: pool,
      difficulty: phaseRecords == null ? null : DifficultyController(phases),
    );
    return ShiftDefinition(
      id: id,
      title: title,
      mode: mode,
      rules: rules,
      goal: ShiftGoal.fromJson(json['goal'] as Map<String, dynamic>, pool),
      previewGuide: json['preview_guide'] as String?,
      beltSurges: BeltSurges(List.unmodifiable(surges)),
    );
  }
}
