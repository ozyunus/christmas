import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_config.dart';
import '../game/shift_session.dart';
import 'game_layout.dart';

const paperInk = Color(0xFF40281E);
const evergreen = Color(0xFF154035);
const snow = Color(0xFFFFFAEC);
const shipLabel = 'SHIP';
const rejectLabel = 'REJECT';

class FactoryBackground extends StatelessWidget {
  const FactoryBackground({
    super.key,
    required this.layout,
    required this.isPlaying,
  });

  final ResponsiveGameLayout layout;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          layout.background,
          key: ValueKey(layout.background),
          fit: BoxFit.cover,
          alignment: layout.backgroundAlignment,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isPlaying
                  ? const [
                      Color(0x65141412),
                      Color(0x11141412),
                      Color(0x9B221612),
                    ]
                  : const [
                      Color(0x5D14221E),
                      Color(0x2B1B221E),
                      Color(0x9A21120D),
                    ],
              stops: const [0, .49, 1],
            ),
          ),
        ),
      ],
    );
  }
}

enum PanelArt {
  menu('panel_menu_blank', 900 / 1120),
  results('panel_results_blank', 900 / 1160),
  pause('panel_pause_blank', 800 / 940),
  tutorial('panel_tutorial_blank', 1000 / 900);

  const PanelArt(this.asset, this.aspect);
  final String asset;
  final double aspect;
}

class FactoryPanel extends StatelessWidget {
  const FactoryPanel({
    super.key,
    required this.art,
    required this.title,
    required this.child,
    this.footer,
    this.footerHeight = 48,
  });

  final PanelArt art;
  final String title;
  final Widget child;
  final Widget? footer;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = min(
            art == PanelArt.tutorial ? 470.0 : 410.0,
            min(constraints.maxWidth, constraints.maxHeight * art.aspect),
          );
          final height = width / art.aspect;
          final isTutorial = art == PanelArt.tutorial;
          final footerInset = height * (isTutorial ? .17 : .143);
          final actionHeight = footer == null ? 0.0 : footerHeight;
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/ui/panels/${art.asset}.png',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    left: width * .15,
                    right: width * .15,
                    top: height * (isTutorial ? .151 : .105),
                    height: height * .077,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            key: ValueKey(title),
                            style: const TextStyle(
                              color: snow,
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.bold,
                              fontSize: 29,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: height * (isTutorial ? .29 : .228),
                    bottom: footerInset + actionHeight,
                    left: width * .139,
                    right: width * .139,
                    child: LayoutBuilder(
                      builder: (context, body) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: body.maxHeight,
                          ),
                          child: Center(
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: paperInk,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (footer case final action?)
                    Positioned(
                      bottom: footerInset,
                      height: actionHeight,
                      left: width * .139,
                      right: width * .139,
                      child: Center(child: action),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FactoryAction extends StatelessWidget {
  const FactoryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.allowTwoLines = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool secondary;
  final bool allowTwoLines;

  static const _buttonArtAspectRatio = 635 / 240;

  @override
  Widget build(BuildContext context) {
    if (secondary) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: evergreen,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        child: Text(label),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 222),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: snow,
            padding: EdgeInsets.zero,
            shape: const StadiumBorder(),
          ),
          child: Center(
            child: AspectRatio(
              aspectRatio: _buttonArtAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/ui/buttons/btn_green_blank.png',
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  FractionallySizedBox(
                    widthFactor: .68,
                    heightFactor: .58,
                    child: LayoutBuilder(builder: _primaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryLabel(BuildContext context, BoxConstraints space) {
    const style = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
    double? wrapWidth;
    if (allowTwoLines) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      // Wrap when a single line would shrink noticeably. Give the longest
      // word enough room before fitting the two lines into the artwork.
      if (painter.width * .84 > space.maxWidth) {
        wrapWidth = max(space.maxWidth, painter.minIntrinsicWidth);
      }
      painter.dispose();
    }

    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: wrapWidth == null ? 1 : 2,
      style: wrapWidth == null ? style : style.copyWith(height: 1),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: wrapWidth == null
          ? text
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wrapWidth),
              child: text,
            ),
    );
  }
}

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.stats,
    required this.secondsLeft,
    required this.onPause,
  });

  final ShiftStats stats;
  final int secondsLeft;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final time =
        '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _HudTile('Score', '${stats.score}', 'score')),
        const SizedBox(width: 4),
        Expanded(child: _HudTile('Time', time, 'timer')),
        const SizedBox(width: 4),
        Expanded(child: _HudTile('Combo', '${stats.combo}', 'combo')),
        const SizedBox(width: 2),
        IconButton(
          key: const ValueKey('Pause'),
          tooltip: 'Pause',
          onPressed: onPause,
          icon: Image.asset('assets/ui/icons/icon_pause.png', width: 35),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ],
    );
  }
}

class _HudTile extends StatelessWidget {
  const _HudTile(this.label, this.value, this.asset);

  final String label;
  final String value;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      value: value,
      excludeSemantics: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 189),
          child: Column(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: snow,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              AspectRatio(
                aspectRatio: 650 / 215,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/ui/hud/hud_${asset}_blank.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned.fill(
                      left: 22,
                      right: 7,
                      top: 3,
                      bottom: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          key: ValueKey('hud-$asset'),
                          style: const TextStyle(
                            color: snow,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DecisionButton extends StatefulWidget {
  const DecisionButton({
    super.key,
    required this.choice,
    required this.giftIndex,
    required this.onChoose,
  });

  final GiftClass choice;
  final int? giftIndex;
  final void Function(int, GiftClass) onChoose;

  @override
  State<DecisionButton> createState() => _DecisionButtonState();
}

class _DecisionButtonState extends State<DecisionButton> {
  int? _pressedGift;

  @override
  Widget build(BuildContext context) {
    final choice = widget.choice;
    final shipsGift = choice == GiftClass.nice;
    final label = shipsGift ? shipLabel : rejectLabel;
    final symbol = shipsGift ? 'check' : 'cross';
    return Semantics(
      button: true,
      label: label,
      enabled: widget.giftIndex != null,
      onTap: widget.giftIndex == null
          ? null
          : () => widget.onChoose(widget.giftIndex!, choice),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressedGift = widget.giftIndex),
        onTapCancel: () => setState(() => _pressedGift = null),
        onTapUp: (_) {
          final gift = _pressedGift;
          setState(() => _pressedGift = null);
          if (gift != null) widget.onChoose(gift, choice);
        },
        child: AnimatedScale(
          scale: _pressedGift == null ? 1 : .96,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 80),
          child: Stack(
            alignment: const Alignment(0, .15),
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/ui/buttons/btn_${choice.name}_3d_blank.png',
                fit: BoxFit.contain,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/ui/icons/icon_$symbol.png',
                        width: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: snow,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
