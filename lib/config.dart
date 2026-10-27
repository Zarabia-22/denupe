import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración central de la app.
/// Lee las credenciales desde `.env` (ver `.env.example`).
abstract final class Config {
  static String get baseUrl {
    final value = dotenv.env['INSFORGE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('INSFORGE_URL no definido en .env');
    }
    return value;
  }

  static String get anonKey {
    final value = dotenv.env['INSFORGE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('INSFORGE_ANON_KEY no definido en .env');
    }
    return value;
  }

  /// URL pública HTTPS de la API FastAPI; nulo si no se ha configurado.
  static String? get aiBaseUrl {
    final value = dotenv.env['DENUPE_IA_URL']?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}
