/// Masks an email for list rows, for example `ab***@example.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email.isEmpty ? '' : '***';
  final local = email.substring(0, at);
  final visible = local.length > 2 ? 2 : 1;
  return '${local.substring(0, visible)}***${email.substring(at)}';
}

/// Keeps only the last four digits of a phone number.
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 4) return '*' * digits.length;
  return '${'*' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
}
