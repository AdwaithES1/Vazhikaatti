import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/panorama.dart';

String getDefaultApiBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8080';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }

  return 'http://localhost:8080';
}

String getApiBaseUrl() {
  final configured = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  return configured.isNotEmpty ? configured : getDefaultApiBaseUrl();
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse(baseUrl ?? getApiBaseUrl());

  final http.Client _client;
  final Uri _baseUri;

  Future<List<Panorama>> getPanoramas() async {
    final response = await _client.get(_baseUri.resolve('/api/panoramas'));
    if (response.statusCode != 200) {
      throw ApiException(
        'Could not load panoramas (HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const ApiException('The panorama API returned an invalid list.');
    }
    return data
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid panorama entry from API.');
          }
          return Panorama.fromJson(item);
        })
        .toList(growable: false);
  }
}
