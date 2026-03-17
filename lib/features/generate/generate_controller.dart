import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GenerateType { url, text, email, phone, wifi }

class GenerateState {
  final GenerateType selectedType;
  final String input;
  final String ssid;
  final String password;
  final String security;

  const GenerateState({
    this.selectedType = GenerateType.text,
    this.input = '',
    this.ssid = '',
    this.password = '',
    this.security = 'WPA',
  });

  String get qrData {
    return switch (selectedType) {
      GenerateType.url => input.isEmpty ? '' : input.startsWith('http') ? input : 'https://$input',
      GenerateType.email => input.isEmpty ? '' : 'mailto:$input',
      GenerateType.phone => input.isEmpty ? '' : 'tel:$input',
      GenerateType.wifi => ssid.isEmpty ? '' : 'WIFI:T:$security;S:$ssid;P:$password;;',
      GenerateType.text => input,
    };
  }

  bool get hasContent => qrData.isNotEmpty && qrData.length <= 2953;

  GenerateState copyWith({
    GenerateType? selectedType,
    String? input,
    String? ssid,
    String? password,
    String? security,
  }) => GenerateState(
    selectedType: selectedType ?? this.selectedType,
    input: input ?? this.input,
    ssid: ssid ?? this.ssid,
    password: password ?? this.password,
    security: security ?? this.security,
  );
}

class GenerateController extends StateNotifier<GenerateState> {
  GenerateController() : super(const GenerateState());

  void selectType(GenerateType type) => state = state.copyWith(selectedType: type, input: '', ssid: '', password: '');
  void setInput(String value) => state = state.copyWith(input: value);
  void setSsid(String value) => state = state.copyWith(ssid: value);
  void setPassword(String value) => state = state.copyWith(password: value);
  void setSecurity(String value) => state = state.copyWith(security: value);
}

// No autoDispose — IndexedStack keeps all tabs in tree; state must survive tab switches
final generateControllerProvider =
    StateNotifierProvider<GenerateController, GenerateState>(
  (_) => GenerateController(),
);
