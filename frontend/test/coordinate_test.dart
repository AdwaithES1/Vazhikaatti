import 'package:campus_street_view/models/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses signed X/Y/Z coordinates from a panorama filename', () {
    final coordinate = Coordinate.fromPanoramaFilename('-1_2_0.jpg');

    expect(coordinate.x, -1);
    expect(coordinate.y, 2);
    expect(coordinate.z, 0);
  });

  test('rejects filenames that do not encode three coordinates', () {
    expect(
      () => Coordinate.fromPanoramaFilename('campus.jpg'),
      throwsFormatException,
    );
  });
}
