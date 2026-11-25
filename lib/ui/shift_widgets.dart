import 'package:flutter/material.dart';

import '../game/shift_catalog.dart';
import '../game/shift_session.dart';
import 'factory_widgets.dart';

class ShiftGoals extends StatelessWidget {
  const ShiftGoals({
    super.key,
    required this.goal,
    this.stats,
    this.onBelt = false,
  });

  final ShiftGoal goal;
  final ShiftStats? stats;
  final bool onBelt;

  @override
  Widget build(BuildContext context) {
    final current = stats;
    final descriptions = [
      if (goal.correct > 0)
        current == null
            ? '${goal.correct} correct'
            : '${current.correct}/${goal.correct} correct',
      if (goal.accuracyPercent > 0)
        current == null
            ? '${goal.accuracyPercent}% accuracy'
            : '${current.accuracyPercent.floor()}% / ${goal.accuracyPercent}% accuracy',
      if (goal.combo > 0)
        current == null
            ? '${goal.combo} combo'
            : '${current.bestCombo}/${goal.combo} best combo',
      for (final entry in goal.shipped.entries)
        current == null
            ? 'Ship ${entry.value} ${_giftName(entry.key, entry.value)}'
            : '${_giftName(entry.key, 1, capitalize: true)} ${current.shipped[entry.key] ?? 0}/${entry.value}',
    ];
    final items = Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final description in descriptions)
          Text(
            description,
            style: TextStyle(
              color: onBelt ? snow : evergreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
    if (!onBelt) return items;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE32A211A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: items,
      ),
    );
  }

  String _giftName(String id, int count, {bool capitalize = false}) {
    final name = id.replaceAll('_', ' ');
    final label = capitalize ? name[0].toUpperCase() + name.substring(1) : name;
    return count == 1 ? label : '${label}s';
  }
}

class CampaignMenu extends StatelessWidget {
  const CampaignMenu({
    super.key,
    required this.content,
    required this.completed,
    required this.onSelect,
    required this.onBack,
  });

  final ShiftCatalog content;
  final Set<String> completed;
  final ValueChanged<ShiftDefinition> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return FactoryPanel(
      art: PanelArt.menu,
      title: 'Play Shifts',
      footer: FactoryAction(label: 'Back', onPressed: onBack, secondary: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final shift in content.campaign) ...[
            if (content.isUnlocked(shift, completed))
              FactoryAction(
                label: shift.title,
                onPressed: () => onSelect(shift),
                secondary: true,
              )
            else
              Text(
                '${shift.title} · Locked',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            Text(
              completed.contains(shift.id)
                  ? '${shift.rules.durationMs ~/ 1000}s · Cleared'
                  : '${shift.rules.durationMs ~/ 1000}s',
              style: const TextStyle(fontSize: 12),
            ),
            ShiftGoals(goal: shift.goal!),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class RoadTripMenu extends StatefulWidget {
  const RoadTripMenu({
    super.key,
    required this.previews,
    required this.onSelect,
    required this.onBack,
  });

  final List<ShiftDefinition> previews;
  final ValueChanged<ShiftDefinition> onSelect;
  final VoidCallback onBack;

  @override
  State<RoadTripMenu> createState() => _RoadTripMenuState();
}

class _RoadTripMenuState extends State<RoadTripMenu> {
  ShiftDefinition? _selected;

  @override
  Widget build(BuildContext context) {
    final preview = _selected;
    if (preview != null) return _previewPanel(preview);
    return FactoryPanel(
      key: const ValueKey('road-trip-regions'),
      art: PanelArt.menu,
      title: "Santa's Road Trip",
      footer: FactoryAction(
        label: 'Back',
        onPressed: widget.onBack,
        secondary: true,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final preview in widget.previews)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _selected = preview),
                style: TextButton.styleFrom(
                  foregroundColor: evergreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      preview.rules.catalog.gifts.first.asset,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        preview.title,
                        textAlign: TextAlign.start,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewPanel(ShiftDefinition preview) {
    final guide = preview.previewGuide;
    return FactoryPanel(
      key: ValueKey(preview.id),
      art: PanelArt.menu,
      title: preview.title,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FactoryAction(
            label: 'Back',
            onPressed: () => setState(() => _selected = null),
            secondary: true,
          ),
          Flexible(
            child: FactoryAction(
              label: 'Play Preview',
              onPressed: () => widget.onSelect(preview),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final gift in preview.rules.catalog.gifts)
                Flexible(
                  child: Image.asset(
                    gift.asset,
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (guide != null) ...[Text(guide), const SizedBox(height: 6)],
          ShiftGoals(goal: preview.goal!),
          const SizedBox(height: 6),
          Text('${preview.rules.durationMs ~/ 1000}-second free preview'),
        ],
      ),
    );
  }
}

class BeltSurgeNotice extends StatelessWidget {
  const BeltSurgeNotice({super.key, required this.state});

  final BeltSurgeState state;

  @override
  Widget build(BuildContext context) {
    final warning = state == BeltSurgeState.warning;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFE5A6) : const Color(0xFFD2F4FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            warning
                ? 'Ice warning · Belt speeds up soon'
                : 'Ice surge · Fast belt',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF192A35),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
