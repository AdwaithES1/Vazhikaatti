import 'dart:io';

import 'package:campus_street_view_backend/routes/api_router.dart';
import 'package:campus_street_view_backend/services/panorama_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('streams panorama images and supports conditional cache requests',
      () async {
    final directory = await Directory.systemTemp.createTemp('campus-images-');
    addTearDown(() => directory.delete(recursive: true));
    final imagesDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}images',
    );
    await imagesDirectory.create();
    final image = File(
      '${imagesDirectory.path}${Platform.pathSeparator}0_0_0.jpg',
    );
    await image.writeAsBytes([1, 2, 3, 4]);
    final service = PanoramaService(
      imagesDirectory: imagesDirectory,
      dataFile:
          File('${directory.path}${Platform.pathSeparator}panoramas.json'),
    );
    final router = createApiRouter(service);

    final response = await router(
      Request('GET', Uri.parse('http://localhost/images/0_0_0.jpg')),
    );

    expect(response.statusCode, 200);
    expect(response.headers['content-length'], '4');
    expect(response.headers['cache-control'], contains('max-age=3600'));
    final etag = response.headers['etag'];
    expect(etag, isNotNull);
    expect(await response.readAsString(), String.fromCharCodes([1, 2, 3, 4]));

    final cachedResponse = await router(
      Request(
        'GET',
        Uri.parse('http://localhost/images/0_0_0.jpg'),
        headers: {'if-none-match': etag!},
      ),
    );

    expect(cachedResponse.statusCode, 304);
    expect(cachedResponse.headers['etag'], etag);
    await cachedResponse.readAsString();
  });
}
