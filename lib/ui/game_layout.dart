import 'dart:math';

import 'package:flutter/widgets.dart';

final class ResponsiveGameLayout {
  ResponsiveGameLayout(Size viewport, EdgeInsets insets)
    : isLandscape = viewport.width > viewport.height,
      isTablet = min(viewport.width, viewport.height) >= 600,
      safeArea = Rect.fromLTRB(
        insets.left,
        insets.top,
        viewport.width - insets.right,
        viewport.height - insets.bottom,
      );

  final bool isTablet;
  final bool isLandscape;
  final Rect safeArea;

  String get background => isTablet && isLandscape
      ? 'assets/backgrounds/factory_ipad_landscape.png'
      : 'assets/backgrounds/factory_iphone_portrait.png';

  Alignment get backgroundAlignment =>
      isTablet && !isLandscape ? const Alignment(0, -.12) : Alignment.center;

  Rect get arena {
    final width = min(safeArea.width - 24, isTablet ? 820.0 : 480.0);
    return Rect.fromLTWH(
      safeArea.center.dx - width / 2,
      safeArea.top,
      width,
      safeArea.height,
    );
  }

  double get beltWidth => arena.width * .98;

  double get beltTop => arena.top + arena.height * (isLandscape ? .60 : .66);

  double get giftSize =>
      min(arena.width * (isTablet ? .30 : .46), arena.height * .26);

  Rect get swipeArea => Rect.fromLTRB(
    arena.left,
    arena.top + arena.height * .19,
    arena.right,
    arena.top + arena.height * .78,
  );
}
