abstract final class AuthValidation {
  static String? name(String? value) {
    final length = (value ?? '').trim().length;
    return length >= 2 && length <= 80
        ? null
        : 'Informe seu nome com 2 a 80 caracteres.';
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    return text.length <= 254 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Informe um e-mail válido.';
  }

  static Map<String, bool> passwordCriteria(String value) => {
    'Pelo menos 8 caracteres': value.length >= 8,
    'Uma letra maiúscula': RegExp(r'[A-Z]').hasMatch(value),
    'Uma letra minúscula': RegExp(r'[a-z]').hasMatch(value),
    'Um número': RegExp(r'[0-9]').hasMatch(value),
    'Um símbolo': RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value),
  };

  static String? password(String? value) =>
      passwordCriteria(value ?? '').values.every((met) => met)
      ? null
      : 'A senha precisa atender a todos os critérios abaixo.';

  static String? signInPassword(String? value) =>
      value == null || value.isEmpty ? 'Informe sua senha.' : null;

  static String? confirmation(String? value, String password) =>
      value == password ? null : 'As senhas precisam ser iguais.';
}
