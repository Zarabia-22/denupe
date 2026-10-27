import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Resultado del clasificador, independiente de la base de datos.
class AiCategorySuggestion {
  const AiCategorySuggestion({
    required this.sugerida,
    this.categoria,
    this.motivo,
  });

  final bool sugerida;
  final String? categoria;
  final String? motivo;

  factory AiCategorySuggestion.fromJson(Map<String, dynamic> json) {
    return AiCategorySuggestion(
      sugerida: json['sugerida'] == true,
      categoria: json['categoria'] as String?,
      motivo: json['motivo'] as String?,
    );
  }
}

/// Cliente HTTP para el microservicio FastAPI de DenuPe (compatible web/móvil).
class AiCategoryService {
  Future<AiCategorySuggestion> sugerirCategoria({
    required String titulo,
    required String descripcion,
  }) async {
    final baseUrl = Config.aiBaseUrl;
    if (baseUrl == null) {
      throw const AiCategoryException(
        'Configura DENUPE_IA_URL para habilitar las sugerencias con IA.',
      );
    }

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/ia/sugerir-categoria',
    );
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const AiCategoryException('La URL del servicio de IA no es válida.');
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'titulo': titulo.trim(),
              'descripcion': descripcion.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw const AiCategoryException(
          'El servicio de IA no pudo procesar la denuncia. Elige una categoría manualmente.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inválida del servicio');
      }
      return AiCategorySuggestion.fromJson(decoded);
    } on TimeoutException {
      throw const AiCategoryException(
        'La sugerencia está tardando demasiado. Puedes elegir una categoría manualmente.',
      );
    } on AiCategoryException {
      rethrow;
    } catch (e) {
      throw AiCategoryException(
        'No se pudo obtener la sugerencia. Puedes elegir una categoría manualmente. ($e)',
      );
    }
  }
}

class AiCategoryException implements Exception {
  const AiCategoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
