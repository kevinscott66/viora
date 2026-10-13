import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveHero extends StatefulWidget {
  const WaveHero({
    super.key,
    required this.accent,
    required this.playing,
    required this.busy,
    this.mood,
    this.onTap,
    this.onClear,
  });
  final Color accent;
  final bool playing, busy;
  final String? mood;
  final VoidCallback? onTap, onClear;
  @override
  State<WaveHero> createState() => _WaveHeroState();
}

class _WaveHeroState extends State<WaveHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      motion.stop();
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(32),
    child: SizedBox(
      height:
          252 + (MediaQuery.textScalerOf(context).scale(30) - 30).clamp(0, 120),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff1b171e)),
          RotationTransition(
            turns: motion,
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                painter: _WavePainter(widget.accent),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: widget.onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  icon: widget.busy
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          widget.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 38,
                        ),
                  label: const Text(
                    'Твоя волна',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                if (widget.mood != null)
                  ActionChip(
                    avatar: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      widget.mood!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: .12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .15),
                    ),
                    onPressed: widget.onClear,
                    tooltip: 'Убрать настроение и включить общую волну',
                  )
                else
                  const Text(
                    'Нажми и поймай свой ритм',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.accent);
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width * .42, size.height * .43);
    const phase = 0.0;
    final area = Rect.fromCircle(center: center, radius: radius * 1.6);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: .28),
            const Color(0xff7b416d).withValues(alpha: .12),
            Colors.transparent,
          ],
        ).createShader(area),
    );
    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      for (var i = 0; i <= 120; i++) {
        final angle = i / 120 * math.pi * 2;
        final r =
            radius *
            (1 +
                .10 * math.sin(angle * 3 + phase + layer * .7) +
                .05 * math.cos(angle * 5 - phase));
        final point =
            center +
            Offset(math.cos(angle) * r * 1.10, math.sin(angle) * r * .88);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, const Color(0xff976fbd), const Color(0xffed8fa5)],
      ).createShader(area);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15 - layer * 3
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = accent.withValues(alpha: .30 - layer * .06),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.accent != accent;
}
