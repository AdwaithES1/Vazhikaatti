import 'coordinate.dart';

class Panorama {
  const Panorama({
    required this.id,
    required this.image,
    required this.coordinate,
    required this.heading,
    this.orientation = const {},
  });

  final String id;
  final String image;
  final Coordinate coordinate;
  final double heading;
  final Map<String, double> orientation;

  Panorama copyWithOrientation(Map<String, double> value) => Panorama(
    id: id,
    image: image,
    coordinate: coordinate,
    heading: heading,
    orientation: Map.unmodifiable(value),
  );

  factory Panorama.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    if (json['id'] is! String || image is! String || json['heading'] is! num) {
      throw const FormatException('Invalid panorama metadata from API.');
    }

    final rawOrientation = json['orientation'];
    final orientation = <String, double>{};
    if (rawOrientation is Map) {
      for (final entry in rawOrientation.entries) {
        if (entry.key is String && entry.value is num) {
          orientation[entry.key as String] = (entry.value as num).toDouble();
        }
      }
    }

    return Panorama(
      id: json['id'] as String,
      image: image,
      coordinate: Coordinate.fromPanoramaFilename(image),
      heading: (json['heading'] as num).toDouble(),
      orientation: Map.unmodifiable(orientation),
    );
  }
}
