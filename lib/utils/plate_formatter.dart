import 'package:flutter/services.dart';

const _ruPlateLetters = 'АВЕКМНОРСТУХ';

const _enToRuPlate = {
  'A': 'А',
  'B': 'В',
  'E': 'Е',
  'K': 'К',
  'M': 'М',
  'H': 'Н',
  'O': 'О',
  'P': 'Р',
  'C': 'С',
  'T': 'Т',
  'Y': 'У',
  'X': 'Х',
};

const _ruLayoutToPlate = {
  'ф': 'А',
  'и': 'В',
  'у': 'Е',
  'р': 'К',
  'ь': 'М',
  'т': 'Н',
  'щ': 'О',
  'з': 'Р',
  'с': 'С',
  'е': 'Т',
  'г': 'У',
  'ч': 'Х',
  'Ф': 'А',
  'И': 'В',
  'У': 'Е',
  'Р': 'К',
  'Ь': 'М',
  'Т': 'Н',
  'Щ': 'О',
  'З': 'Р',
  'С': 'С',
  'Е': 'Т',
  'Г': 'У',
  'Ч': 'Х',
};

String _toPlateChar(String c) {
  final upperC = c.toUpperCase();
  if (_ruPlateLetters.contains(upperC)) return upperC;

  final ruC = _enToRuPlate[upperC] ?? _ruLayoutToPlate[upperC];
  if (ruC != null && _ruPlateLetters.contains(ruC)) return ruC;

  return '';
}

/// Валидация гос. номера.
String? validatePlate(String? v) {
  if (v == null || v.length < 8) {
    return 'Слишком короткий номер';
  }
  if (!RegExp(r'^[АВЕКМНОРСТУХ]{1}\d{3}[АВЕКМНОРСТУХ]{2}\d{2,3}$')
      .hasMatch(v.toUpperCase())) {
    return 'Неверный формат (напр. А000АА77)';
  }
  return null;
}

/// Форматтер для ввода российских гос. номеров автомобилей.
class PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    final buf = StringBuffer();
    int pos = 0;
    for (int i = 0; i < raw.length && pos < 9; i++) {
      final c = raw[i];
      if (pos == 0 || pos == 4 || pos == 5) {
        final ruC = _toPlateChar(c);
        if (ruC.isNotEmpty) {
          buf.write(ruC);
          pos++;
        }
      } else if ((pos >= 1 && pos <= 3) || (pos >= 6 && pos <= 8)) {
        if (RegExp(r'[0-9]').hasMatch(c)) {
          buf.write(c);
          pos++;
        }
      }
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
