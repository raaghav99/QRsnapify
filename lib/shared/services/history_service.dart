import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scan_result.dart';

class HistoryService {
  static const _key = 'scan_history';
  static const _maxItems = 500;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<ScanResult>> getHistory() async {
    final prefs = await _p;
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
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(result.toJson()));
    if (raw.length > _maxItems) raw.removeAt(0);
    await prefs.setStringList(_key, raw);
  }

  Future<void> deleteById(String id) async {
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];
    // Clean up associated PDFs before removing entries
    for (final e in raw) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        if (map['id'] == id) {
          _deletePdfForContent(prefs, map['content'] as String?);
        }
      } catch (_) {}
    }
    raw.removeWhere((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return true;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  /// Deletes multiple items in a single read-filter-write cycle.
  Future<void> deleteByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];
    // Clean up associated PDFs before removing entries
    for (final e in raw) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        if (ids.contains(map['id'])) {
          _deletePdfForContent(prefs, map['content'] as String?);
        }
      } catch (_) {}
    }
    raw.removeWhere((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return ids.contains(map['id']);
      } catch (_) {
        return true;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  Future<void> toggleFavourite(String id) async {
    final prefs = await _p;
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
    final prefs = await _p;
    // Delete all associated PDFs
    final raw = prefs.getStringList(_key) ?? [];
    for (final e in raw) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        _deletePdfForContent(prefs, map['content'] as String?);
      } catch (_) {}
    }
    await prefs.remove(_key);
  }

  /// Deletes the saved PDF file and its SharedPreferences entry for a given content string.
  void _deletePdfForContent(SharedPreferences prefs, String? content) {
    if (content == null) return;
    final key = 'pdf_path_${content.hashCode}';
    final path = prefs.getString(key);
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
      prefs.remove(key);
    }
  }
}
