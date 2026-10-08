import 'coordinate.dart';

class Panorama {
  const Panorama({
    required this.id,
    required this.image,
    required this.coordinate,
    required this.heading,
  });

  final String id;
  final String image;
  final Coordinate coordinate;
  final double heading;

  Map<String, Object> toJson() => {
    'id': id,
    'image': image,
    ...coordinate.toJson(),
    'heading': heading,
  };
}
