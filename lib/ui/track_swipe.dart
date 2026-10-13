import 'package:flutter/material.dart';

/// Horizontal gestures stay separate from page scrolling and seek controls.
class TrackSwipe extends StatefulWidget {
  const TrackSwipe({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrevious,
  });
  final Widget child;
  final Future<void> Function() onNext, onPrevious;
  @override
  State<TrackSwipe> createState() => _TrackSwipeState();
}

class _TrackSwipeState extends State<TrackSwipe> {
  double distance = 0;
  bool switching = false;
  Future<void> finish(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    if (switching || (distance.abs() < 56 && velocity.abs() < 500)) return;
    final direction = velocity.abs() >= 500 ? velocity : distance;
    switching = true;
    try {
      await (direction < 0 ? widget.onNext() : widget.onPrevious());
    } finally {
      switching = false;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => distance = 0,
    onHorizontalDragUpdate: (event) => distance += event.primaryDelta ?? 0,
    onHorizontalDragCancel: () => distance = 0,
    onHorizontalDragEnd: finish,
    child: widget.child,
  );
}
