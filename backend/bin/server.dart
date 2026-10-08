import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/routes/api_router.dart';
import '../lib/services/panorama_service.dart';

Future<void> main() async {
  final projectDirectory = File.fromUri(Platform.script).parent.parent;
  final panoramaService = PanoramaService(
    imagesDirectory: Directory(
      '${projectDirectory.path}${Platform.pathSeparator}images',
    ),
    dataFile: File(
      '${projectDirectory.path}${Platform.pathSeparator}data'
      '${Platform.pathSeparator}panoramas.json',
    ),
  );

  final handler = Pipeline()
      .addMiddleware(logErrors())
      .addMiddleware(corsHeaders())
      .addHandler(
        Cascade().add(createApiRouter(panoramaService)).handler,
      );

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    int.parse(Platform.environment['PORT'] ?? '8080'),
  );
  stdout.writeln('Campus Street View API listening on http://${server.address.host}:${server.port}');
}
