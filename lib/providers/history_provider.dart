import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/scan_result.dart';

const _kBoxName = 'scan_history';

final historyBoxProvider = Provider<Box<ScanResult>>((ref) {
  return Hive.box<ScanResult>(_kBoxName);
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<ScanResult>>((ref) {
  final box = ref.watch(historyBoxProvider);
  return HistoryNotifier(box);
});

/// Top-5 slice used by HomeScreen — avoids rebuilding the full list.
final recentHistoryProvider = Provider<List<ScanResult>>((ref) {
  return ref.watch(historyProvider).take(5).toList();
});

class HistoryNotifier extends StateNotifier<List<ScanResult>> {
  HistoryNotifier(this._box) : super(_box.values.toList().reversed.toList());

  final Box<ScanResult> _box;

  /// Persists [content] as a new scan entry and returns the created record.
  Future<ScanResult> add(String content) async {
    final result = ScanResult(
      content: content,
      scannedAt: DateTime.now(),
      type: ScanResult.detectType(content),
    );
    await _box.add(result);
    // Prepend to avoid re-reading the entire box on every add.
    state = [result, ...state];
    return result;
  }

  Future<void> remove(ScanResult result) async {
    await result.delete();
    // Filter in-memory state instead of re-reading the box.
    state = state.where((r) => r.key != result.key).toList();
  }

  Future<void> clear() async {
    await _box.clear();
    state = [];
  }
}
