import 'package:campus_street_view/models/coordinate.dart';
import 'package:campus_street_view/models/panorama.dart';
import 'package:campus_street_view/models/panorama_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

Panorama panorama(String filename) => Panorama(
  id: filename.substring(0, filename.length - 4),
  image: filename,
  coordinate: Coordinate.fromPanoramaFilename(filename),
  heading: 0,
);

void main() {
  test('creates only existing one-coordinate-step neighbors', () {
    final left = panorama('0_4_0.jpg');
    final current = panorama('1_4_0.jpg');
    final right = panorama('2_4_0.jpg');
    final diagonal = panorama('2_5_0.jpg');
    final distant = panorama('1_7_0.jpg');
    final graph = PanoramaGraph([left, current, right, diagonal, distant]);

    expect(graph.neighborsOf(current), {
      PanoramaDirection.left: left,
      PanoramaDirection.right: right,
    });
    expect(graph.targetFrom(left, PanoramaDirection.right), current);
    expect(graph.targetFrom(right, PanoramaDirection.left), current);
    expect(graph.targetFrom(current, PanoramaDirection.forward), isNull);
    expect(graph.targetFrom(current, PanoramaDirection.backward), isNull);
  });

  test('does not jump across a missing node or connect diagonally', () {
    final origin = panorama('0_0_0.jpg');
    final twoStepsAway = panorama('0_2_0.jpg');
    final diagonal = panorama('1_1_0.jpg');
    final graph = PanoramaGraph([origin, twoStepsAway, diagonal]);

    expect(graph.neighborsOf(origin), isEmpty);
    expect(graph.neighborsOf(twoStepsAway), isEmpty);
    expect(graph.neighborsOf(diagonal), isEmpty);
    expect(graph.edges, isEmpty);
  });

  test(
    'builds each visual edge once and keeps different Z levels separate',
    () {
      final lower = panorama('0_0_0.jpg');
      final right = panorama('1_0_0.jpg');
      final upperFloor = panorama('1_0_1.jpg');
      final graph = PanoramaGraph([lower, right, upperFloor]);

      expect(graph.edges, hasLength(1));
      expect(graph.edges.single.start, lower);
      expect(graph.edges.single.end, right);
      expect(graph.neighborsOf(upperFloor), isEmpty);
    },
  );

  test('produces no navigation directions for an isolated panorama', () {
    final current = panorama('0_0_0.jpg');

    expect(
      findDirectionalPanoramas(panoramas: [current], current: current),
      isEmpty,
    );
  });

  test('finds a shortest route through connected panorama nodes', () {
    final start = panorama('0_0_0.jpg');
    final middle = panorama('1_0_0.jpg');
    final destination = panorama('1_1_0.jpg');
    final graph = PanoramaGraph([start, middle, destination]);

    expect(graph.shortestPath(from: start, to: destination), [
      start,
      middle,
      destination,
    ]);
    expect(graph.directionTo(start, middle), PanoramaDirection.right);
    expect(graph.directionTo(middle, destination), PanoramaDirection.forward);
    expect(graph.shortestPath(from: start, to: start), [start]);
  });

  test('returns no route when endpoints are disconnected', () {
    final start = panorama('0_0_0.jpg');
    final destination = panorama('4_0_0.jpg');
    final graph = PanoramaGraph([start, destination]);

    expect(graph.shortestPath(from: start, to: destination), isNull);
  });
}
