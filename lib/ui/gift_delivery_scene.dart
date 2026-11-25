import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';

import '../game/game_config.dart';

const christmasMorningAsset = 'assets/backgrounds/christmas_morning.png';
const giftDeliveryDuration = Duration(seconds: 6);
const giftDeliveryFinaleDuration = Duration(seconds: 9);

class GiftDeliveryScene extends StatefulWidget {
  const GiftDeliveryScene({
    super.key,
    required this.images,
    required this.gifts,
    required this.arriving,
    required this.finale,
    required this.onFinished,
  });

  final Images images;
  final List<Gift> gifts;
  final Set<String> arriving;
  final bool finale;
  final VoidCallback onFinished;

  @override
  State<GiftDeliveryScene> createState() => _GiftDeliverySceneState();
}

class _GiftDeliverySceneState extends State<GiftDeliveryScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scene;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _scene =
        AnimationController(
          vsync: this,
          duration: widget.finale
              ? giftDeliveryFinaleDuration
              : giftDeliveryDuration,
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          !_finished &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        _scene.forward();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    if (state == AppLifecycleState.resumed) {
      _scene.forward();
    } else {
      _scene.stop(canceled: false);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gifts = widget.gifts
        .take(_giftPositions.length)
        .map(
          (gift) => (
            image: widget.images.fromCache(gift.asset),
            artBottom: gift.artBottom,
            arriving: widget.arriving.contains(gift.id),
            train: gift.id == 'toy_train',
          ),
        )
        .toList(growable: false);
    final names = widget.gifts.map((gift) => gift.id.replaceAll('_', ' '));
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          image: true,
          label: names.isEmpty
              ? 'A lit Christmas tree in a quiet living room'
              : 'Under the Christmas tree: ${names.join(', ')}',
          child: CustomPaint(
            painter: _ChristmasMorningPainter(
              room: widget.images.fromCache(christmasMorningAsset),
              gifts: gifts,
              timeline: _scene,
              finale: widget.finale,
              reduceMotion: MediaQuery.disableAnimationsOf(context),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFECCC),
                backgroundColor: const Color(0xDD352016),
                minimumSize: const Size(64, 48),
                side: const BorderSide(color: Color(0x80F4C578)),
              ),
              child: const Text('Skip'),
            ),
          ),
        ),
      ],
    );
  }
}

typedef _DeliverySprite = ({
  ui.Image image,
  double artBottom,
  bool arriving,
  bool train,
});

// Coordinates are normalized to the room artwork, so the shadows and toys
// stay on the same floorboards as the camera moves and the viewport crops.
const _giftPositions = [
  (x: .50, y: .724, width: .124),
  (x: .385, y: .756, width: .105),
  (x: .615, y: .761, width: .106),
  (x: .444, y: .822, width: .103),
  (x: .554, y: .834, width: .104),
  (x: .496, y: .883, width: .091),
];

class _ChristmasMorningPainter extends CustomPainter {
  _ChristmasMorningPainter({
    required this.room,
    required this.gifts,
    required this.timeline,
    required this.finale,
    required this.reduceMotion,
  }) : super(repaint: reduceMotion ? null : timeline);

  final ui.Image room;
  final List<_DeliverySprite> gifts;
  final Animation<double> timeline;
  final bool finale;
  final bool reduceMotion;

  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _shadow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  @override
  void paint(Canvas canvas, Size size) {
    final t = reduceMotion ? 1.0 : timeline.value;
    final approach = Curves.easeInOutCubic.transform((t / .73).clamp(0, 1));
    final pullback = finale
        ? Curves.easeInOut.transform(((t - .77) / .23).clamp(0, 1))
        : 0.0;
    final camera = (approach - .74 * pullback) * (reduceMotion ? 0 : 1);
    final width = room.width.toDouble();
    final height = room.height.toDouble();
    final scale =
        math.max(size.width / width, size.height / height) * (1 + .14 * camera);
    final frame = Size(size.width / scale, size.height / scale);
    final landscape = size.width > size.height;
    final floorReveal = Curves.easeInOut.transform((t / .6).clamp(0, 1));
    final centerY = landscape
        ? math.max(
            (.44 + .048 * camera) * height,
            (.78 + .125 * floorReveal) * height - frame.height / 2,
          )
        : (.50 + .048 * camera) * height;
    final centerX = (landscape ? .50 : .43 + .07 * approach) * width;
    final left = (centerX - frame.width / 2)
        .clamp(0.0, math.max(0.0, width - frame.width))
        .toDouble();
    final top = (centerY - frame.height / 2)
        .clamp(0.0, math.max(0.0, height - frame.height))
        .toDouble();

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    canvas.translate(-left, -top);
    _paint.color = Colors.white;
    canvas.drawImage(room, Offset.zero, _paint);
    for (final (index, gift) in gifts.indexed) {
      final position = _giftPositions[index];
      final reveal = gift.arriving
          ? Curves.easeOutCubic.transform(
              ((t - .19 - index * .06) / .29).clamp(0, 1),
            )
          : 1.0;
      final roll = finale && gift.train && !reduceMotion
          ? math.sin((((t - .68) / .26).clamp(0, 1)) * math.pi) * .034
          : 0.0;
      final x = (position.x + roll) * width;
      final y = position.y * height;
      final giftWidth = position.width * width;
      final giftHeight = giftWidth * gift.image.height / gift.image.width;
      _shadow.color = const Color(0xA3361709).withValues(alpha: reveal * .54);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + 2),
          width: giftWidth * .72,
          height: giftWidth * .15,
        ),
        _shadow,
      );
      _paint.color = Colors.white.withValues(alpha: reveal);
      canvas.drawImageRect(
        gift.image,
        Rect.fromLTWH(
          0,
          0,
          gift.image.width.toDouble(),
          gift.image.height.toDouble(),
        ),
        Rect.fromLTWH(
          x - giftWidth / 2,
          y - giftHeight * gift.artBottom - (1 - reveal) * 20,
          giftWidth,
          giftHeight,
        ),
        _paint,
      );
    }
    canvas.restore();

    final fade = 1 - Curves.easeOut.transform((t / .17).clamp(0, 1));
    if (fade > 0) {
      canvas.drawColor(
        const Color(0xFF1F1008).withValues(alpha: fade),
        BlendMode.srcOver,
      );
    }
  }

  @override
  bool shouldRepaint(_ChristmasMorningPainter oldDelegate) =>
      room != oldDelegate.room ||
      gifts != oldDelegate.gifts ||
      timeline != oldDelegate.timeline ||
      finale != oldDelegate.finale ||
      reduceMotion != oldDelegate.reduceMotion;
}
