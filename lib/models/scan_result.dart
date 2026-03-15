import 'package:hive/hive.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  final String content;

  @HiveField(1)
  final DateTime scannedAt;

  @HiveField(2)
  final String type; // 'url' | 'text' | 'email' | 'phone' | 'other'

  ScanResult({
    required this.content,
    required this.scannedAt,
    required this.type,
  });

  static String detectType(String content) {
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return 'url';
    } else if (content.startsWith('mailto:') ||
        RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(content)) {
      return 'email';
    } else if (content.startsWith('tel:') ||
        RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(content)) {
      return 'phone';
    }
    return 'text';
  }
}
