import 'dart:math';

class SecureToken {
  SecureToken._();

  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int _alphabetSize = 32;

  static String generate({int length = 24}) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < length; index++) {
      buffer.write(_alphabet[random.nextInt(_alphabetSize)]);
    }
    return buffer.toString();
  }

  static String normalize(String value) {
    final upper = value.toUpperCase();
    final buffer = StringBuffer();
    for (final code in upper.codeUnits) {
      final char = String.fromCharCode(code);
      if (_alphabet.contains(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String formatCode(String token) {
    final normalized = normalize(token);
    final groups = <String>[];
    for (var index = 0; index < normalized.length; index += 4) {
      final end = index + 4 > normalized.length ? normalized.length : index + 4;
      groups.add(normalized.substring(index, end));
    }
    return groups.join('-');
  }

  static bool isWellFormed(String value, {int expectedLength = 24}) {
    return normalize(value).length == expectedLength;
  }
}
