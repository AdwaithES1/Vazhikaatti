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
    final stat = await file.stat();
    final etag = '"${stat.size}-${stat.modified.microsecondsSinceEpoch}"';
    final cacheHeaders = {
      'cache-control': 'public, max-age=3600, must-revalidate',
      'etag': etag,
      'last-modified': HttpDate.format(stat.modified),
    };
    final ifNoneMatch = request.headers['if-none-match'];
    if (ifNoneMatch != null &&
        ifNoneMatch
            .split(',')
            .map((value) => value.trim())
            .any((value) => value == etag || value == '*')) {
      return Response(304, headers: cacheHeaders);
    }

    return Response.ok(
      file.openRead(),
      headers: {
        ...cacheHeaders,
        'content-type': 'image/jpeg',
        'content-length': '${stat.size}',
      },
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
