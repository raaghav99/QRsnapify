import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GenerateType { url, text, email, phone, sms, wifi, upi, whatsapp, vcard, geo }

class GenerateState {
  final GenerateType selectedType;
  final String input;
  // WiFi fields
  final String ssid;
  final String password;
  final String security;
  // SMS fields
  final String smsPhone;
  final String smsBody;
  // UPI fields
  final String upiVpa;
  final String upiName;
  final String upiAmount;
  // WhatsApp fields
  final String waPhone;
  final String waMessage;
  // vCard fields
  final String vcardName;
  final String vcardPhone;
  final String vcardEmail;
  final String vcardOrg;
  // Geo fields
  final String geoLat;
  final String geoLng;
  final String geoLabel;

  const GenerateState({
    this.selectedType = GenerateType.text,
    this.input = '',
    this.ssid = '',
    this.password = '',
    this.security = 'WPA',
    this.smsPhone = '',
    this.smsBody = '',
    this.upiVpa = '',
    this.upiName = '',
    this.upiAmount = '',
    this.waPhone = '',
    this.waMessage = '',
    this.vcardName = '',
    this.vcardPhone = '',
    this.vcardEmail = '',
    this.vcardOrg = '',
    this.geoLat = '',
    this.geoLng = '',
    this.geoLabel = '',
  });

  String get qrData {
    return switch (selectedType) {
      GenerateType.url => input.isEmpty ? '' : input.startsWith('http') ? input : 'https://$input',
      GenerateType.email => input.isEmpty ? '' : 'mailto:$input',
      GenerateType.phone => input.isEmpty ? '' : 'tel:$input',
      GenerateType.wifi => ssid.isEmpty ? '' : 'WIFI:T:$security;S:$ssid;P:$password;;',
      GenerateType.text => input,
      GenerateType.sms => smsPhone.isEmpty ? '' : 'smsto:$smsPhone:$smsBody',
      GenerateType.upi => upiVpa.isEmpty ? '' : _buildUpiString(),
      GenerateType.whatsapp => waPhone.isEmpty ? '' : 'https://wa.me/${waPhone.replaceAll(RegExp(r'[^\d]'), '')}${waMessage.isNotEmpty ? '?text=${Uri.encodeComponent(waMessage)}' : ''}',
      GenerateType.vcard => vcardName.isEmpty ? '' : _buildVcardString(),
      GenerateType.geo => (geoLat.isEmpty || geoLng.isEmpty)
          ? ''
          : 'geo:$geoLat,$geoLng${geoLabel.isNotEmpty ? '?q=${Uri.encodeComponent(geoLabel)}' : ''}',
    };
  }

  String _buildUpiString() {
    final params = <String>['pa=$upiVpa'];
    if (upiName.isNotEmpty) params.add('pn=${Uri.encodeComponent(upiName)}');
    if (upiAmount.isNotEmpty) params.add('am=$upiAmount');
    params.add('cu=INR');
    return 'upi://pay?${params.join('&')}';
  }

  String _buildVcardString() {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:$vcardName',
      'N:;$vcardName;;;',
    ];
    if (vcardPhone.isNotEmpty) lines.add('TEL:$vcardPhone');
    if (vcardEmail.isNotEmpty) lines.add('EMAIL:$vcardEmail');
    if (vcardOrg.isNotEmpty) lines.add('ORG:$vcardOrg');
    lines.add('END:VCARD');
    return lines.join('\n');
  }

  bool get hasContent => qrData.isNotEmpty && qrData.length <= 2953;

  GenerateState copyWith({
    GenerateType? selectedType,
    String? input,
    String? ssid,
    String? password,
    String? security,
    String? smsPhone,
    String? smsBody,
    String? upiVpa,
    String? upiName,
    String? upiAmount,
    String? waPhone,
    String? waMessage,
    String? vcardName,
    String? vcardPhone,
    String? vcardEmail,
    String? vcardOrg,
    String? geoLat,
    String? geoLng,
    String? geoLabel,
  }) => GenerateState(
    selectedType: selectedType ?? this.selectedType,
    input: input ?? this.input,
    ssid: ssid ?? this.ssid,
    password: password ?? this.password,
    security: security ?? this.security,
    smsPhone: smsPhone ?? this.smsPhone,
    smsBody: smsBody ?? this.smsBody,
    upiVpa: upiVpa ?? this.upiVpa,
    upiName: upiName ?? this.upiName,
    upiAmount: upiAmount ?? this.upiAmount,
    waPhone: waPhone ?? this.waPhone,
    waMessage: waMessage ?? this.waMessage,
    vcardName: vcardName ?? this.vcardName,
    vcardPhone: vcardPhone ?? this.vcardPhone,
    vcardEmail: vcardEmail ?? this.vcardEmail,
    vcardOrg: vcardOrg ?? this.vcardOrg,
    geoLat: geoLat ?? this.geoLat,
    geoLng: geoLng ?? this.geoLng,
    geoLabel: geoLabel ?? this.geoLabel,
  );
}

class GenerateController extends StateNotifier<GenerateState> {
  GenerateController() : super(const GenerateState());

  void selectType(GenerateType type) => state = GenerateState(selectedType: type);
  void setInput(String value) => state = state.copyWith(input: value);
  void setSsid(String value) => state = state.copyWith(ssid: value);
  void setPassword(String value) => state = state.copyWith(password: value);
  void setSecurity(String value) => state = state.copyWith(security: value);
  void setSmsPhone(String value) => state = state.copyWith(smsPhone: value);
  void setSmsBody(String value) => state = state.copyWith(smsBody: value);
  void setUpiVpa(String value) => state = state.copyWith(upiVpa: value);
  void setUpiName(String value) => state = state.copyWith(upiName: value);
  void setUpiAmount(String value) => state = state.copyWith(upiAmount: value);
  void setWaPhone(String value) => state = state.copyWith(waPhone: value);
  void setWaMessage(String value) => state = state.copyWith(waMessage: value);
  void setVcardName(String value) => state = state.copyWith(vcardName: value);
  void setVcardPhone(String value) => state = state.copyWith(vcardPhone: value);
  void setVcardEmail(String value) => state = state.copyWith(vcardEmail: value);
  void setVcardOrg(String value) => state = state.copyWith(vcardOrg: value);
  void setGeoLat(String value) => state = state.copyWith(geoLat: value);
  void setGeoLng(String value) => state = state.copyWith(geoLng: value);
  void setGeoLabel(String value) => state = state.copyWith(geoLabel: value);
}

// No autoDispose — IndexedStack keeps all tabs in tree; state must survive tab switches
final generateControllerProvider =
    StateNotifierProvider<GenerateController, GenerateState>(
  (_) => GenerateController(),
);
