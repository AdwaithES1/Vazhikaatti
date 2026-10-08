final _panoramaFilenamePattern = RegExp(r'^(-?\d+)_(-?\d+)_(-?\d+)$');

class Coordinate {
  const Coordinate({required this.x, required this.y, required this.z});

  final int x;
  final int y;
  final int z;

  Map<String, int> toJson() => {'x': x, 'y': y, 'z': z};

  static Coordinate parsePanoramaFilename(String filename) {
    final basename = filename.split(RegExp(r'[/\\]')).last;
    final extension = basename.lastIndexOf('.');
    final stem = extension < 0 ? basename : basename.substring(0, extension);
    final match = _panoramaFilenamePattern.firstMatch(stem);

    if (match == null) {
      throw FormatException(
        'Panorama filename must follow x_y_z.jpg: $filename',
      );
    }

    return Coordinate(
      x: int.parse(match[1]!),
      y: int.parse(match[2]!),
      z: int.parse(match[3]!),
    );
  }
}
