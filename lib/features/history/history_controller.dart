import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class HistoryController {
  final Ref ref;
  HistoryController(this.ref);

  Future<void> delete(String id) async {
    await ref.read(historyProvider.notifier).delete(id);
  }

  Future<void> deleteMany(Set<String> ids) async {
    await ref.read(historyProvider.notifier).deleteMany(ids);
  }

  Future<void> deleteAll() async {
    await ref.read(historyProvider.notifier).deleteAll();
  }
}

final historyControllerProvider = Provider((ref) => HistoryController(ref));
