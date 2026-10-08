import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coordinate.dart';
import '../models/panorama.dart';
import '../models/panorama_navigation.dart';

class CoordinateMap extends StatelessWidget {
  const CoordinateMap({
    required this.panoramas,
    required this.graph,
    this.currentPanorama,
    this.selectedPanorama,
    this.route = const [],
    this.onPanoramaSelected,
    super.key,
  });

  final List<Panorama> panoramas;
  final PanoramaGraph graph;
  final Panorama? currentPanorama;
  final Panorama? selectedPanorama;
  final List<Panorama> route;
  final ValueChanged<Panorama>? onPanoramaSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final projection = _MapProjection(panoramas, size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onPanoramaSelected == null
              ? null
              : (details) {
                  Panorama? nearest;
                  var nearestDistance = 24.0;
                  for (final panorama in panoramas) {
                    final point = projection.pointFor(panorama.coordinate);
                    final distance = (point - details.localPosition).distance;
                    if (distance <= nearestDistance) {
                      nearest = panorama;
                      nearestDistance = distance;
                    }
                  }
                  if (nearest != null) onPanoramaSelected!(nearest);
                },
          child: CustomPaint(
            size: size,
            painter: _CoordinateMapPainter(
              panoramas: panoramas,
              graph: graph,
              projection: projection,
              currentPanorama: currentPanorama,
              selectedPanorama: selectedPanorama,
              route: route,
            ),
          ),
        );
      },
    );
  }
}

class _MapProjection {
  _MapProjection(this.panoramas, this.size) {
    final coordinates = panoramas.map((panorama) => panorama.coordinate);
    minX = coordinates.map((coordinate) => coordinate.x).reduce(math.min);
    maxX = coordinates.map((coordinate) => coordinate.x).reduce(math.max);
    minY = coordinates.map((coordinate) => coordinate.y).reduce(math.min);
    maxY = coordinates.map((coordinate) => coordinate.y).reduce(math.max);

    const padding = 34.0;
    final usableWidth = math.max(1.0, size.width - padding * 2);
    final usableHeight = math.max(1.0, size.height - padding * 2);
    final spanX = math.max(1, maxX - minX);
    final spanY = math.max(1, maxY - minY);
    scale = math.min(usableWidth / spanX, usableHeight / spanY);
    origin = Offset(
      (size.width - (maxX - minX) * scale) / 2 - minX * scale,
      (size.height + (maxY + minY) * scale) / 2,
    );
  }

  final List<Panorama> panoramas;
  final Size size;
  late final int minX;
  late final int maxX;
  late final int minY;
  late final int maxY;
  late final double scale;
  late final Offset origin;

  Offset pointFor(Coordinate coordinate) => Offset(
    origin.dx + coordinate.x * scale,
    origin.dy - coordinate.y * scale,
  );
}

class _CoordinateMapPainter extends CustomPainter {
  const _CoordinateMapPainter({
    required this.panoramas,
    required this.graph,
    required this.projection,
    required this.currentPanorama,
    required this.selectedPanorama,
    required this.route,
  });

  final List<Panorama> panoramas;
  final PanoramaGraph graph;
  final _MapProjection projection;
  final Panorama? currentPanorama;
  final Panorama? selectedPanorama;
  final List<Panorama> route;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xff17232d),
    );

    final axisPaint = Paint()
      ..color = const Color(0xff526774)
      ..strokeWidth = 1;
    final edgePaint = Paint()
      ..color = const Color(0xff8296a2)
      ..strokeWidth = math.max(1.5, projection.scale * 0.055)
      ..strokeCap = StrokeCap.round;
    final zeroX = projection.pointFor(const Coordinate(x: 0, y: 0, z: 0)).dx;
    final zeroY = projection.pointFor(const Coordinate(x: 0, y: 0, z: 0)).dy;
    if (zeroY >= 0 && zeroY <= size.height) {
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), axisPaint);
    }
    if (zeroX >= 0 && zeroX <= size.width) {
      canvas.drawLine(Offset(zeroX, 0), Offset(zeroX, size.height), axisPaint);
    }

    for (final edge in graph.edges) {
      canvas.drawLine(
        projection.pointFor(edge.start.coordinate),
        projection.pointFor(edge.end.coordinate),
        edgePaint,
      );
    }

    if (route.length > 1) {
      final routePaint = Paint()
        ..color = const Color(0xff54dcaa)
        ..strokeWidth = math.min(7, math.max(4, projection.scale * 0.12))
        ..strokeCap = StrokeCap.round;
      for (var index = 0; index < route.length - 1; index++) {
        canvas.drawLine(
          projection.pointFor(route[index].coordinate),
          projection.pointFor(route[index + 1].coordinate),
          routePaint,
        );
      }
    }

    _drawLabel(
      canvas,
      '+Y ↑',
      const Offset(10, 8),
      color: const Color(0xffc2ced4),
    );
    _drawLabel(
      canvas,
      '+X →',
      Offset(math.max(8, size.width - 46), math.max(8, size.height - 22)),
      color: const Color(0xffc2ced4),
    );

    final neighborIds = currentPanorama == null
        ? <String>{}
        : graph
              .neighborsOf(currentPanorama!)
              .values
              .map((panorama) => panorama.id)
              .toSet();
    for (final panorama in panoramas) {
      final point = projection.pointFor(panorama.coordinate);
      final isCurrent = panorama.id == currentPanorama?.id;
      final isSelected = panorama.id == selectedPanorama?.id;
      final isNeighbor = neighborIds.contains(panorama.id);
      final isRouteStart = route.isNotEmpty && panorama.id == route.first.id;
      final isRouteEnd = route.isNotEmpty && panorama.id == route.last.id;

      if (isCurrent || isSelected || isRouteStart || isRouteEnd) {
        canvas.drawCircle(
          point,
          isRouteStart || isRouteEnd ? 10 : 11,
          Paint()
            ..color = isCurrent
                ? const Color(0x6654dcaa)
                : isSelected
                ? const Color(0x66ffc078)
                : isRouteStart
                ? const Color(0x6654dcaa)
                : const Color(0x6678c8ff),
        );
      }
      canvas.drawCircle(
        point,
        isCurrent || isSelected ? 6 : 4.5,
        Paint()
          ..color = isCurrent
              ? const Color(0xff54dcaa)
              : isSelected
              ? const Color(0xffffc078)
              : isRouteStart
              ? const Color(0xff54dcaa)
              : isRouteEnd
              ? const Color(0xff78c8ff)
              : isNeighbor
              ? const Color(0xff78c8ff)
              : const Color(0xffd4dfe4),
      );
      canvas.drawCircle(
        point,
        isCurrent || isSelected ? 6 : 4.5,
        Paint()
          ..color = const Color(0xff101820)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String label,
    Offset position, {
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _CoordinateMapPainter oldDelegate) =>
      oldDelegate.panoramas != panoramas ||
      oldDelegate.graph != graph ||
      oldDelegate.currentPanorama != currentPanorama ||
      oldDelegate.selectedPanorama != selectedPanorama ||
      oldDelegate.route != route ||
      oldDelegate.projection.size != projection.size;
}
