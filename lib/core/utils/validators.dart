class AppValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Введите email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Введите корректный email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < 8) return 'Минимум 8 символов';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Добавьте заглавную букву';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Добавьте строчную букву';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Добавьте цифру';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value))
      return 'Добавьте спецсимвол';
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) return 'Введите $fieldName';
    return null;
  }
}
