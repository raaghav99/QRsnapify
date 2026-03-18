import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_result.dart';
import '../shared/services/calibration_service.dart';
import '../shared/services/age_scale_service.dart';
import '../shared/services/history_service.dart';

// Services
final calibrationServiceProvider = Provider((_) => CalibrationService());
final ageScaleServiceProvider = Provider((_) => AgeScaleService());
final historyServiceProvider = Provider((_) => HistoryService());

// Button height
final buttonHeightProvider = StateProvider<double>((ref) => 52.0);

// Text scale
final textScaleProvider = StateProvider<double>((ref) => 1.0);

// Onboarding
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

// History
class HistoryNotifier extends AsyncNotifier<List<ScanResult>> {
  @override
  Future<List<ScanResult>> build() async {
    final service = ref.read(historyServiceProvider);
    return service.getHistory();
  }

  Future<void> add(ScanResult result) async {
    final service = ref.read(historyServiceProvider);
    await service.addScan(result);
    state = AsyncData(await service.getHistory());
  }

  Future<void> delete(String id) async {
    final service = ref.read(historyServiceProvider);
    await service.deleteById(id);
    state = AsyncData(await service.getHistory());
  }

  Future<void> deleteMany(Set<String> ids) async {
    final service = ref.read(historyServiceProvider);
    await service.deleteByIds(ids);
    state = AsyncData(await service.getHistory());
  }

  Future<void> toggleFavourite(String id) async {
    final service = ref.read(historyServiceProvider);
    await service.toggleFavourite(id);
    state = AsyncData(await service.getHistory());
  }

  Future<void> deleteAll() async {
    final service = ref.read(historyServiceProvider);
    await service.clearAll();
    state = const AsyncData([]);
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<ScanResult>>(
  HistoryNotifier.new,
);
