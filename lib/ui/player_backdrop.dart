import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/track.dart';
import 'artwork_provider.dart';
import 'shared.dart';

/// Album colours stay behind the content; a dark scrim protects white labels
/// even when the source artwork is almost entirely white.
class PlayerBackdrop extends StatelessWidget {
  const PlayerBackdrop({super.key, required this.track, required this.child});
  final Track track;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: motion(context, 700),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  child: SizedBox.expand(
                    key: ValueKey(track.artworkPath ?? track.color),
                    child: track.artworkPath == null
                        ? ColoredBox(color: track.color)
                        : ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 45,
                              sigmaY: 45,
                              tileMode: TileMode.clamp,
                            ),
                            child: Image(
                              image: ResizeImage.resizeIfNeeded(
                                512,
                                null,
                                artworkProvider(track.artworkPath!),
                              ),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) =>
                                  ColoredBox(color: track.color),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .35, .65, 1],
                colors: [
                  Color(0xb3000000),
                  Color(0x99000000),
                  Color(0xbf000000),
                  Color(0xe6000000),
                ],
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
