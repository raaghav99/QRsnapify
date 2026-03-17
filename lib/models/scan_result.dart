enum QRType { url, email, phone, wifi, text }

class ScanResult {
  final String id;
  final String content;
  final QRType type;
  final DateTime scannedAt;

  const ScanResult({
    required this.id,
    required this.content,
    required this.type,
    required this.scannedAt,
  });

  static QRType detectType(String content) {
    final lower = content.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('www.')) {
      return QRType.url;
    } else if (lower.startsWith('mailto:') || RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(lower)) {
      return QRType.email;
    } else if (lower.startsWith('tel:') || RegExp(r'^\+?[\d\s\-\(\)]{7,}$').hasMatch(lower)) {
      return QRType.phone;
    } else if (lower.startsWith('wifi:')) {
      return QRType.wifi;
    }
    return QRType.text;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'type': type.name,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    id: json['id'] as String,
    content: json['content'] as String,
    type: QRType.values.firstWhere((e) => e.name == json['type'], orElse: () => QRType.text),
    scannedAt: DateTime.parse(json['scannedAt'] as String),
  );

  static int _counter = 0;

  static ScanResult create(String content) {
    _counter++;
    final id = '${DateTime.now().millisecondsSinceEpoch}_$_counter';
    return ScanResult(
      id: id,
      content: content,
      type: detectType(content),
      scannedAt: DateTime.now(),
    );
  }
}
