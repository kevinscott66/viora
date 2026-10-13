import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The cover takes the space left by the actual text and controls, rather than
/// forcing a width-sized square plus a fixed spacer beyond the safe viewport.
class PlayerLayout extends StatelessWidget {
  const PlayerLayout({
    super.key,
    required this.artwork,
    required this.details,
    required this.controls,
    required this.footer,
    required this.wide,
  });
  final Widget artwork, details, controls, footer;
  final bool wide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 32 : 24, 12, wide ? 32 : 24, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (wide) {
          final size = math.min(
            (constraints.maxWidth - 32) / 2,
            constraints.maxHeight,
          );
          return SingleChildScrollView(
            key: const ValueKey('player-scroll'),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: SizedBox.square(dimension: size, child: artwork),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        details,
                        const SizedBox(height: 20),
                        controls,
                        footer,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          key: const ValueKey('player-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox.square(
                          dimension: constraints.maxWidth,
                          child: artwork,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  details,
                  const SizedBox(height: 16),
                  controls,
                  footer,
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
