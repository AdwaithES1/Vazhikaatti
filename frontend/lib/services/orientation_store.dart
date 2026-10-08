import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/panorama.dart';

class OrientationStore {
  static const _storageKey = 'panorama_orientation_assignments';

  Future<Map<String, Panorama>> loadInto(List<Panorama> panoramas) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null) return {for (final panorama in panoramas) panorama.id: panorama};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {for (final panorama in panoramas) panorama.id: panorama};
    return {
      for (final panorama in panoramas)
        panorama.id: panorama.copyWithOrientation({
          ...panorama.orientation,
          if (decoded[panorama.id] is Map)
            for (final entry in (decoded[panorama.id] as Map).entries)
              if (entry.key is String && entry.value is num)
                entry.key as String: (entry.value as num).toDouble(),
        }),
    };
  }

  Future<void> save(Panorama panorama) async {
    final preferences = await SharedPreferences.getInstance();
    final assignments = _read(preferences);
    assignments[panorama.id] = panorama.orientation;
    await preferences.setString(_storageKey, jsonEncode(assignments));
  }

  Future<void> clear(Panorama panorama) async {
    final preferences = await SharedPreferences.getInstance();
    final assignments = _read(preferences)..remove(panorama.id);
    await preferences.setString(_storageKey, jsonEncode(assignments));
  }

  Map<String, Map<String, double>> _read(SharedPreferences preferences) {
    final raw = preferences.getString(_storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: {
            for (final assignment in (entry.value as Map).entries)
              if (assignment.key is String && assignment.value is num)
                assignment.key as String: (assignment.value as num).toDouble(),
          },
    };
  }
}
