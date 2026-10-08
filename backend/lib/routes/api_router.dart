import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/panorama_service.dart';

Router createApiRouter(PanoramaService panoramas) {
  final router = Router();

  router.get('/api/health', (Request request) {
    return Response.ok(
      '{"status":"ok"}',
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/api/panoramas', (Request request) async {
    final items = await panoramas.getAll();
    return Response.ok(
      jsonEncode(items.map((panorama) => panorama.toJson()).toList()),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/api/panoramas/<id>', (Request request, String id) async {
    final panorama = await panoramas.getById(id);
    if (panorama == null) return Response.notFound('Panorama not found.');
    return Response.ok(
      jsonEncode(panorama.toJson()),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/images/<image>', (Request request, String image) async {
    final file = await panoramas.imageByName(image);
    if (file == null) return Response.notFound('Panorama image not found.');
    return Response.ok(
      await file.readAsBytes(),
      headers: {'content-type': 'image/jpeg', 'cache-control': 'no-cache'},
    );
  });

  return router;
}

Middleware corsHeaders() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'access-control-allow-origin': '*',
            'access-control-allow-methods': 'GET, OPTIONS',
            'access-control-allow-headers': 'Origin, Content-Type, Accept',
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'access-control-allow-origin': '*',
        },
      );
    };
  };
}

Middleware logErrors() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (error, stackTrace) {
        stderr.writeln('Request ${request.url} failed: $error\n$stackTrace');
        return Response.internalServerError(
          body: 'Internal server error.',
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      }
    };
  };
}
