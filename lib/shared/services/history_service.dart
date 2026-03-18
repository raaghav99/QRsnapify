import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scan_result.dart';

class HistoryService {
  static const _key = 'scan_history';
  static const _maxItems = 500;

  Future<List<ScanResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final results = <ScanResult>[];
    for (final e in raw) {
      try {
        results.add(ScanResult.fromJson(jsonDecode(e) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupted entries rather than crashing
      }
    }
    return results.reversed.toList();
  }

  Future<void> addScan(ScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(result.toJson()));
    if (raw.length > _maxItems) raw.removeAt(0);
    await prefs.setStringList(_key, raw);
  }

  Future<void> deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return true; // Remove corrupted entries
      }
    });
    await prefs.setStringList(_key, raw);
  }

  /// Deletes multiple items in a single read-filter-write cycle.
  Future<void> deleteByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return ids.contains(map['id']);
      } catch (_) {
        return true; // Remove corrupted entries
      }
    });
    await prefs.setStringList(_key, raw);
  }

  Future<void> toggleFavourite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.map((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        if (map['id'] == id) {
          map['isFavourite'] = !(map['isFavourite'] as bool? ?? false);
          return jsonEncode(map);
        }
        return e;
      } catch (_) {
        return e; // Keep unparseable entries as-is
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
