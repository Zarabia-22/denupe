import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración central de la aplicación.
abstract final class Config {
  static String get apiBaseUrl {
    final value = dotenv.env['DENUPE_API_URL']?.trim();
    final base = (value == null || value.isEmpty)
        ? 'https://denupe-backend.onrender.com'
        : value;
    return base.replaceFirst(RegExp(r'/+$'), '');
  }
}
