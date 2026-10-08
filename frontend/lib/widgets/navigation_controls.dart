import 'package:flutter/material.dart';

import '../models/panorama_navigation.dart';

class NavigationControls extends StatelessWidget {
  const NavigationControls({
    required this.availableDirections,
    required this.onNavigate,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    this.compact = false,
    this.nextDirection,
    super.key,
  });

  final Set<PanoramaDirection> availableDirections;
  final ValueChanged<PanoramaDirection> onNavigate;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final bool compact;
  final PanoramaDirection? nextDirection;

  double get _buttonSize => compact ? 26 : 38;
  double get _utilitySize => compact ? 24 : 34;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 4 : 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _directionRow(null, PanoramaDirection.forward, null),
            _directionRow(
              PanoramaDirection.left,
              null,
              PanoramaDirection.right,
            ),
            _directionRow(null, PanoramaDirection.backward, null),
            Divider(height: compact ? 4 : 8, color: const Color(0xff394852)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _utilityButton('Zoom out', Icons.remove, onZoomOut),
                _utilityButton(
                  'Reset view',
                  Icons.center_focus_strong_outlined,
                  onReset,
                ),
                _utilityButton('Zoom in', Icons.add, onZoomIn),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionRow(
    PanoramaDirection? left,
    PanoramaDirection? center,
    PanoramaDirection? right,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _directionButton(left),
        _directionButton(center),
        _directionButton(right),
      ],
    );
  }

  Widget _directionButton(PanoramaDirection? direction) {
    if (direction == null) {
      return SizedBox(width: _buttonSize, height: _buttonSize);
    }
    final enabled = availableDirections.contains(direction);
    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: IconButton(
        tooltip: _directionLabel(direction),
        onPressed: enabled ? () => onNavigate(direction) : null,
        style: IconButton.styleFrom(
          backgroundColor: direction == nextDirection
              ? const Color(0xff54dcaa)
              : enabled
              ? const Color(0xff245543)
              : const Color(0xff26323a),
          foregroundColor: direction == nextDirection
              ? const Color(0xff10221b)
              : enabled
              ? const Color(0xff8ff0c9)
              : const Color(0xff687780),
          disabledForegroundColor: const Color(0xff687780),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        icon: Icon(_directionIcon(direction), size: compact ? 14 : 19),
      ),
    );
  }

  Widget _utilityButton(String label, IconData icon, VoidCallback onPressed) =>
      SizedBox(
        width: _utilitySize,
        height: _utilitySize,
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          color: Colors.white,
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: 18),
        ),
      );

  String _directionLabel(PanoramaDirection direction) => switch (direction) {
    PanoramaDirection.forward => 'Forward',
    PanoramaDirection.backward => 'Backward',
    PanoramaDirection.left => 'Left',
    PanoramaDirection.right => 'Right',
  };

  IconData _directionIcon(PanoramaDirection direction) => switch (direction) {
    PanoramaDirection.forward => Icons.arrow_upward,
    PanoramaDirection.backward => Icons.arrow_downward,
    PanoramaDirection.left => Icons.arrow_back,
    PanoramaDirection.right => Icons.arrow_forward,
  };
}
