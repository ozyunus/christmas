import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const santaSleighAsset = 'assets/transitions/santa_sleigh.png';
const shiftFlightDuration = Duration(seconds: 2);

class ShiftFlightTransition extends StatefulWidget {
  const ShiftFlightTransition({
    super.key,
    required this.destination,
    required this.sleigh,
    required this.onFinished,
  });

  final String destination;
  final ui.Image sleigh;
  final VoidCallback onFinished;

  @override
  State<ShiftFlightTransition> createState() => _ShiftFlightTransitionState();
}

class _ShiftFlightTransitionState extends State<ShiftFlightTransition>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flight;
  bool _finished = false;

  bool get _isForeground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: shiftFlightDuration,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_handleFlightFrame);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isForeground) _flight.forward();
    });
  }

  void _handleFlightFrame() {
    if (_finished || _flight.value < 1) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_finished) _flight.forward();
    } else {
      _flight.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Flying to ${widget.destination}',
      liveRegion: true,
      excludeSemantics: true,
      child: AbsorbPointer(
        child: ColoredBox(
          color: const Color(0xA50B132C),
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final spriteWidth = math.min(width * .76, 560.0);
                final spriteHeight =
                    spriteWidth * widget.sleigh.height / widget.sleigh.width;
                final moonSize = math.min(width * .24, 140.0);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: width * .69 - moonSize / 2,
                      top: height * .34 - moonSize / 2,
                      width: moonSize,
                      height: moonSize,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFFFF8D9), Color(0xFFFFE7B5)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x78FFD299),
                              blurRadius: 36,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _flight,
                      child: RawImage(
                        image: widget.sleigh,
                        width: spriteWidth,
                        height: spriteHeight,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                      builder: (context, sprite) {
                        final progress = _flight.value;
                        final left = reduceMotion
                            ? (width - spriteWidth) / 2
                            : (width + spriteWidth * 1.10) * progress -
                                  spriteWidth * .77;
                        final rise = reduceMotion
                            ? .08
                            : math.sin(progress * math.pi) * .10;
                        return Positioned(
                          left: left,
                          top: height * (.44 - rise) - spriteHeight / 2,
                          child: sprite!,
                        );
                      },
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: height * .14,
                      child: Text(
                        widget.destination,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFFFFF8E6),
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              shadows: [
                                const Shadow(
                                  color: Colors.black,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
