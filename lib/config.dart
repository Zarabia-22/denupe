import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración central de la app.
/// Lee las credenciales y URLs desde `.env` (ver `.env.example`).
abstract final class Config {
  static String get apiBaseUrl {
    final value = dotenv.env['DENUPE_API_URL']?.trim();
    return (value == null || value.isEmpty) ? 'https://denupe-backend.onrender.com' : value;
  }

  static String get baseUrl {
    final value = dotenv.env['INSFORGE_URL']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('INSFORGE_URL no definido en .env');
    }
    return value;
  }

  static String get anonKey {
    final value = dotenv.env['INSFORGE_ANON_KEY']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('INSFORGE_ANON_KEY no definido en .env');
    }
    return value;
  }

}
