import 'package:flutter/material.dart';

import '../models/panorama.dart';

class PositionOverlay extends StatelessWidget {
  const PositionOverlay({required this.panorama, super.key});

  final Panorama panorama;

  @override
  Widget build(BuildContext context) {
    final coordinate = panorama.coordinate;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CURRENT POSITION · GROUND FLOOR',
                style: TextStyle(
                  color: Color(0xff9eb0bc),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'X: ${coordinate.x}   Y: ${coordinate.y}   Z: ${coordinate.z}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
