import 'dart:convert';
import 'dart:io';

import '../models/coordinate.dart';
import '../models/panorama.dart';

class PanoramaService {
  PanoramaService({required this.imagesDirectory, required this.dataFile});

  final Directory imagesDirectory;
  final File dataFile;

  Future<List<Panorama>> getAll() async {
    final data = jsonDecode(await dataFile.readAsString());
    if (data is! List) {
      throw const FormatException('Panorama data must be a JSON array.');
    }

    final metadataByImage = <String, Map<String, Object>>{};
    for (final row in data) {
      if (row is! Map<String, dynamic> ||
          row['image'] is! String ||
          row['id'] is! String ||
          row['heading'] is! num) {
        throw const FormatException(
          'Each panorama metadata entry needs id, image, and numeric heading.',
        );
      }
      metadataByImage[row['image'] as String] = {
        'id': row['id'] as String,
        'heading': (row['heading'] as num).toDouble(),
      };
    }

    if (!await imagesDirectory.exists()) {
      throw FileSystemException(
        'Panorama image directory does not exist.',
        imagesDirectory.path,
      );
    }

    final images = await imagesDirectory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => file.path.toLowerCase().endsWith('.jpg'))
        .toList();
    images.sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last));

    final panoramas = <Panorama>[];
    for (final file in images) {
      final image = file.uri.pathSegments.last;
      final coordinate = Coordinate.parsePanoramaFilename(image);
      final metadata = metadataByImage[image];
      panoramas.add(
        Panorama(
          id: metadata?['id'] as String? ?? 'pano_${image.substring(0, image.length - 4)}',
          image: image,
          coordinate: coordinate,
          heading: metadata?['heading'] as double? ?? 0,
        ),
      );
    }

    return panoramas;
  }

  Future<Panorama?> getById(String id) async {
    for (final panorama in await getAll()) {
      if (panorama.id == id) return panorama;
    }
    return null;
  }

  Future<File?> imageByName(String image) async {
    final file = File('${imagesDirectory.path}${Platform.pathSeparator}$image');
    if (!await file.exists() || file.uri.pathSegments.last != image) return null;
    return file;
  }
}
