import 'panorama.dart';

enum PanoramaDirection { forward, backward, left, right }

class PanoramaGraphEdge {
  const PanoramaGraphEdge(this.start, this.end);

  final Panorama start;
  final Panorama end;
}

class PanoramaGraph {
  PanoramaGraph(Iterable<Panorama> panoramas) {
    final nodesByCoordinate = <(int, int, int), Panorama>{
      for (final panorama in panoramas)
        (panorama.coordinate.x, panorama.coordinate.y, panorama.coordinate.z):
            panorama,
    };
    final neighbors = <String, Map<PanoramaDirection, Panorama>>{};
    final edges = <PanoramaGraphEdge>[];

    for (final panorama in nodesByCoordinate.values) {
      final coordinate = panorama.coordinate;
      final nodeNeighbors = <PanoramaDirection, Panorama>{};
      final candidates = <PanoramaDirection, (int, int, int)>{
        PanoramaDirection.right: (coordinate.x + 1, coordinate.y, coordinate.z),
        PanoramaDirection.left: (coordinate.x - 1, coordinate.y, coordinate.z),
        PanoramaDirection.forward: (
          coordinate.x,
          coordinate.y + 1,
          coordinate.z,
        ),
        PanoramaDirection.backward: (
          coordinate.x,
          coordinate.y - 1,
          coordinate.z,
        ),
      };

      for (final entry in candidates.entries) {
        final neighbor = nodesByCoordinate[entry.value];
        if (neighbor != null) nodeNeighbors[entry.key] = neighbor;
      }
      neighbors[panorama.id] = Map.unmodifiable(nodeNeighbors);

      for (final direction in const [
        PanoramaDirection.right,
        PanoramaDirection.forward,
      ]) {
        final neighbor = nodeNeighbors[direction];
        if (neighbor != null) edges.add(PanoramaGraphEdge(panorama, neighbor));
      }
    }

    _neighborsById = Map.unmodifiable(neighbors);
    this.edges = List.unmodifiable(edges);
  }

  late final Map<String, Map<PanoramaDirection, Panorama>> _neighborsById;
  late final List<PanoramaGraphEdge> edges;

  Map<PanoramaDirection, Panorama> neighborsOf(Panorama panorama) =>
      _neighborsById[panorama.id] ?? const {};

  Panorama? targetFrom(Panorama panorama, PanoramaDirection direction) =>
      neighborsOf(panorama)[direction];

  PanoramaDirection? directionTo(Panorama from, Panorama to) {
    for (final entry in neighborsOf(from).entries) {
      if (entry.value.id == to.id) return entry.key;
    }
    return null;
  }

  List<Panorama>? shortestPath({required Panorama from, required Panorama to}) {
    if (!_neighborsById.containsKey(from.id) ||
        !_neighborsById.containsKey(to.id)) {
      return null;
    }
    if (from.id == to.id) return [from];

    final previousById = <String, String?>{from.id: null};
    final panoramasById = <String, Panorama>{from.id: from};
    final queue = <Panorama>[from];
    for (var index = 0; index < queue.length; index++) {
      final current = queue[index];
      for (final neighbor in neighborsOf(current).values) {
        if (previousById.containsKey(neighbor.id)) continue;
        previousById[neighbor.id] = current.id;
        panoramasById[neighbor.id] = neighbor;
        if (neighbor.id == to.id) {
          final path = <Panorama>[neighbor];
          var previousId = current.id;
          while (previousId != from.id) {
            path.add(panoramasById[previousId]!);
            previousId = previousById[previousId]!;
          }
          path.add(from);
          return path.reversed.toList(growable: false);
        }
        queue.add(neighbor);
      }
    }
    return null;
  }
}

Map<PanoramaDirection, Panorama> findDirectionalPanoramas({
  required List<Panorama> panoramas,
  required Panorama current,
}) => PanoramaGraph(panoramas).neighborsOf(current);
