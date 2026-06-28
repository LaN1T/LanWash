import 'package:flutter/services.dart';

/// Маска телефона: +7 (999) 000-00-00
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Нормализуем: всегда 7 в начале
    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = '7${digits.substring(1)}';
    } else if (digits.isNotEmpty) {
      digits = '7$digits';
    } else {
      return newValue.copyWith(
          text: '+7', selection: const TextSelection.collapsed(offset: 2));
    }
    final buf = StringBuffer('+7');
    if (digits.length > 1) {
      final area = digits.substring(1, digits.length.clamp(1, 4));
      buf.write(' ($area');
      if (digits.length >= 4) buf.write(') ');
    }
    if (digits.length > 4) {
      buf.write(digits.substring(4, digits.length.clamp(4, 7)));
    }
    if (digits.length > 7) {
      buf.write('-${digits.substring(7, digits.length.clamp(7, 9))}');
    }
    if (digits.length > 9) {
      buf.write('-${digits.substring(9, digits.length.clamp(9, 11))}');
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
