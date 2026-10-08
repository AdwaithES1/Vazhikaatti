import 'dart:io';

import 'package:campus_street_view_backend/models/coordinate.dart';
import 'package:campus_street_view_backend/services/panorama_service.dart';
import 'package:test/test.dart';

void main() {
  group('Coordinate.parsePanoramaFilename', () {
    test('parses positive and negative local coordinates', () {
      final coordinate = Coordinate.parsePanoramaFilename('-1_2_0.jpg');

      expect(coordinate.toJson(), {'x': -1, 'y': 2, 'z': 0});
    });

    test('rejects filenames without three integer coordinates', () {
      expect(
        () => Coordinate.parsePanoramaFilename('campus.jpg'),
        throwsFormatException,
      );
    });
  });

  test('discovers all panorama files and derives their positions', () async {
    final directory = await Directory.systemTemp.createTemp('campus-panos-');
    addTearDown(() => directory.delete(recursive: true));
    final images = Directory('${directory.path}${Platform.pathSeparator}images');
    await images.create();
    await File('${images.path}${Platform.pathSeparator}0_0_0.jpg').create();
    await File('${images.path}${Platform.pathSeparator}2_3_0.jpg').create();
    final dataFile = File('${directory.path}${Platform.pathSeparator}panoramas.json');
    await dataFile.writeAsString('''
[
  {"id":"pano_start","image":"0_0_0.jpg","heading":15}
]
''');

    final panoramas = await PanoramaService(
      imagesDirectory: images,
      dataFile: dataFile,
    ).getAll();

    expect(panoramas, hasLength(2));
    expect(panoramas.first.id, 'pano_start');
    expect(panoramas.first.coordinate.toJson(), {'x': 0, 'y': 0, 'z': 0});
    expect(panoramas.first.heading, 15);
    expect(panoramas.last.id, 'pano_2_3_0');
    expect(panoramas.last.coordinate.toJson(), {'x': 2, 'y': 3, 'z': 0});
  });
}
