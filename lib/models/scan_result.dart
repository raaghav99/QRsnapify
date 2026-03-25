enum QRType { url, email, phone, wifi, text, upi }

class ScanResult {
  final String id;
  final String content;
  final QRType type;
  final DateTime scannedAt;
  final bool isFavourite;

  const ScanResult({
    required this.id,
    required this.content,
    required this.type,
    required this.scannedAt,
    this.isFavourite = false,
  });

  static QRType detectType(String content) {
    final lower = content.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('www.')) {
      return QRType.url;
    } else if (lower.startsWith('mailto:') || RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(lower)) {
      return QRType.email;
    } else if (lower.startsWith('tel:') || RegExp(r'^\+[\d\s\-\(\)]{6,}$').hasMatch(lower)) {
      // Require `tel:` prefix OR international format (starts with +)
      // Plain digit strings without `tel:` are treated as text to avoid misclassifying
      // product codes, version numbers, or other numeric QR content as phone numbers
      return QRType.phone;
    } else if (lower.startsWith('wifi:')) {
      return QRType.wifi;
    } else if (lower.startsWith('upi:')) {
      return QRType.upi;
    }
    return QRType.text;
  }

  ScanResult copyWith({bool? isFavourite}) => ScanResult(
    id: id,
    content: content,
    type: type,
    scannedAt: scannedAt,
    isFavourite: isFavourite ?? this.isFavourite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'type': type.name,
    'scannedAt': scannedAt.toIso8601String(),
    'isFavourite': isFavourite,
  };

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as String;
    var type = QRType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => QRType.text,
    );
    // Retroactively upgrade entries saved as 'text' before UPI type was added
    if (type == QRType.text && content.toLowerCase().startsWith('upi:')) {
      type = QRType.upi;
    }
    return ScanResult(
      id: json['id'] as String,
      content: content,
      type: type,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      isFavourite: json['isFavourite'] as bool? ?? false,
    );
  }

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
