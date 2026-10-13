import 'package:flutter/material.dart';
import '../models/track.dart';
import 'artwork_provider.dart';

Duration motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
const secondary = Color(0xffc2bdc2);

class Cover extends StatelessWidget {
  const Cover(this.track, {super.key, this.size, this.radius = 8});
  final Track track;
  final double? size;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: track.artworkPath == null
        ? fallback()
        : Image(
            image: artworkProvider(track.artworkPath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            semanticLabel: 'Обложка ${track.title}',
            errorBuilder: (_, _, _) => fallback(),
          ),
  );
  Widget fallback() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [track.color, const Color(0xff211d39)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, c) => Center(
        child: Icon(
          Icons.album_rounded,
          color: Colors.white70,
          size: (c.maxWidth * .48).clamp(24, 150),
        ),
      ),
    ),
  );
}

class Vinyl extends StatelessWidget {
  const Vinyl({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Positioned(
        right: 0,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xff101012),
                Color(0xff3a3a3d),
                Color(0xff101012),
                Color(0xff27272a),
                Color(0xff101012),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffe6cf92),
              ),
              child: const Center(
                child: Icon(Icons.circle, size: 8, color: Color(0xff242124)),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        child: Transform.rotate(
          angle: -.06,
          child: Cover(emptyTrack, size: 170, radius: 3),
        ),
      ),
    ],
  );
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.selected,
    required this.onPressed,
  });
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: selected ? 'Убрать из избранного' : 'В избранное',
    isSelected: selected,
    onPressed: onPressed,
    icon: Icon(
      selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: selected ? const Color(0xffffbac8) : Colors.white,
    ),
  );
}
