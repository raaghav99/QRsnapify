import 'package:hive/hive.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  final String content;

  @HiveField(1)
  final DateTime scannedAt;

  @HiveField(2)
  final String type; // 'url' | 'text' | 'email' | 'phone'

  ScanResult({
    required this.content,
    required this.scannedAt,
    required this.type,
  });

  static final _emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  static final _phoneRegExp = RegExp(r'^\+?[\d\s\-()]{7,}$');

  static String detectType(String content) {
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return 'url';
    } else if (content.startsWith('mailto:') ||
        _emailRegExp.hasMatch(content)) {
      return 'email';
    } else if (content.startsWith('tel:') || _phoneRegExp.hasMatch(content)) {
      return 'phone';
    }
    return 'text';
  }
}
