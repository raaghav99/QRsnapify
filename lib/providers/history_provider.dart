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

class HistoryNotifier extends StateNotifier<List<ScanResult>> {
  HistoryNotifier(this._box) : super(_box.values.toList().reversed.toList());

  final Box<ScanResult> _box;

  Future<void> add(String content) async {
    final result = ScanResult(
      content: content,
      scannedAt: DateTime.now(),
      type: ScanResult.detectType(content),
    );
    await _box.add(result);
    state = _box.values.toList().reversed.toList();
  }

  Future<void> remove(ScanResult result) async {
    await result.delete();
    state = _box.values.toList().reversed.toList();
  }

  Future<void> clear() async {
    await _box.clear();
    state = [];
  }
}
