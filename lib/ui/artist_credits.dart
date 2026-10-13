import 'package:flutter/material.dart';
import '../models/artist.dart';

/// Every credited artist has an independent, accessible navigation target.
class ArtistCredits extends StatelessWidget {
  const ArtistCredits({
    super.key,
    required this.artists,
    required this.onSelected,
  });
  final List<ArtistCollection> artists;
  final ValueChanged<ArtistCollection> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final artist in artists)
        Semantics(
          label: 'Открыть исполнителя ${artist.info.name}',
          button: true,
          excludeSemantics: true,
          child: TextButton(
            key: ValueKey(artist.info.name),
            onPressed: () => onSelected(artist),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffeee0e4),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            child: Text(
              artist.info.name,
              textAlign: TextAlign.center,
              softWrap: true,
              style: const TextStyle(
                fontFamily: 'ArtistSans',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
    ],
  );
}
