import 'package:flutter/material.dart';

/// Follows lyric changes until the listener deliberately browses the text.
class LyricsFollowView extends StatefulWidget {
  const LyricsFollowView({
    super.key,
    required this.active,
    required this.followEnabled,
    required this.count,
    required this.itemBuilder,
  });
  final int active, count;
  final bool followEnabled;
  final IndexedWidgetBuilder itemBuilder;
  @override
  State<LyricsFollowView> createState() => LyricsFollowViewState();
}

class LyricsFollowViewState extends State<LyricsFollowView> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  bool _browsing = false;
  int? _last;
  double? _height;

  void resume() {
    setState(() {
      _browsing = false;
      _last = null;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(double height) {
    if (!widget.followEnabled || _browsing || widget.active < 0) return;
    if (_last == widget.active && _height == height) return;
    _last = widget.active;
    _height = height;
    final index = widget.active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _browsing ||
          !widget.followEnabled ||
          widget.active != index) {
        return;
      }
      final target = _keys[index]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant LyricsFollowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.followEnabled && widget.followEnabled) _last = null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _follow(constraints.maxHeight);
      return Stack(
        children: [
          NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) {
                setState(() => _browsing = true);
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: constraints.maxHeight / 2,
              ),
              child: Column(
                children: List.generate(
                  widget.count,
                  (index) => KeyedSubtree(
                    key: _keys.putIfAbsent(index, GlobalKey.new),
                    child: widget.itemBuilder(context, index),
                  ),
                ),
              ),
            ),
          ),
          if (_browsing && widget.followEnabled && widget.active >= 0)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: resume,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('К текущей строке'),
                ),
              ),
            ),
        ],
      );
    },
  );
}
