import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class AiPublicEntity {
  const AiPublicEntity({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ambito,
    this.direccion,
    this.telefono,
    this.sitioWeb,
  });

  final String id;
  final String nombre;
  final String tipo;
  final String? direccion;
  final String? telefono;
  final String? sitioWeb;
  final Map<String, String> ambito;

  factory AiPublicEntity.fromJson(Map<String, dynamic> json) {
    final rawAmbito = json['ambito'];
    final ambito = <String, String>{};
    if (rawAmbito is Map) {
      rawAmbito.forEach((key, value) {
        if (value != null) ambito[key.toString()] = value.toString();
      });
    }
    return AiPublicEntity(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      sitioWeb: json['sitio_web'] as String?,
      ambito: ambito,
    );
  }
}

class AiEntitySuggestion {
  const AiEntitySuggestion({
    required this.sugerida,
    required this.motivo,
    this.entidad,
  });

  final bool sugerida;
  final String motivo;
  final AiPublicEntity? entidad;

  factory AiEntitySuggestion.fromJson(Map<String, dynamic> json) {
    final rawEntity = json['entidad'];
    return AiEntitySuggestion(
      sugerida: json['sugerida'] == true,
      motivo: json['motivo']?.toString() ?? 'No se encontró una entidad verificable.',
      entidad: rawEntity is Map<String, dynamic>
          ? AiPublicEntity.fromJson(rawEntity)
          : null,
    );
  }
}

/// Cliente del endpoint HU-IA02 del backend FastAPI.
class AiEntityService {

  /// Obtiene instituciones elegibles para que el ciudadano las seleccione manualmente.
  Future<List<AiPublicEntity>> listarEntidadesDisponibles({
    required String categoria,
    required String departamento,
    required String provincia,
    required String distrito,
    double? latitud,
    double? longitud,
  }) async {
    final baseUrl = Config.aiBaseUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw const AiEntityException('Configura DENUPE_IA_URL para consultar el catálogo de instituciones.');
    }
    final base = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/entidades/disponibles');
    final uri = base.replace(queryParameters: {
      'categoria': categoria,
      'departamento': departamento,
      'provincia': provincia,
      'distrito': distrito,
      if (latitud != null) 'latitud': latitud.toString(),
      if (longitud != null) 'longitud': longitud.toString(),
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const AiEntityException('No se pudo cargar el catálogo de instituciones.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['entidades'] is! List) {
        throw const FormatException('Respuesta inválida del catálogo');
      }
      return (decoded['entidades'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AiPublicEntity.fromJson)
          .toList();
    } on TimeoutException {
      throw const AiEntityException('El catálogo está tardando demasiado en responder.');
    } on AiEntityException {
      rethrow;
    } catch (_) {
      throw const AiEntityException('No se pudo conectar con el catálogo de instituciones.');
    }
  }

  Future<AiEntitySuggestion> sugerirEntidad({
    required String categoria,
    required String departamento,
    required String provincia,
    required String distrito,
    required String titulo,
    required String descripcion,
    double? latitud,
    double? longitud,
  }) async {
    final baseUrl = Config.aiBaseUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw const AiEntityException('Configura DENUPE_IA_URL para habilitar la recomendación de entidades.');
    }

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/ia/sugerir-entidad',
    );
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const AiEntityException('La URL del servicio de IA no es válida.');
    }

    final payload = <String, dynamic>{
      'categoria': categoria,
      'departamento': departamento,
      'provincia': provincia,
      'distrito': distrito,
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      if (latitud != null && longitud != null) ...{
        'latitud': latitud,
        'longitud': longitud,
      },
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw const AiEntityException(
          'El servicio no pudo recomendar una entidad. Puedes continuar con la selección manual.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inválida del servicio');
      }
      return AiEntitySuggestion.fromJson(decoded);
    } on TimeoutException {
      throw const AiEntityException(
        'La consulta está tardando demasiado. Puedes seleccionar una entidad manualmente.',
      );
    } on AiEntityException {
      rethrow;
    } catch (_) {
      throw const AiEntityException(
        'No se pudo conectar con el servicio de recomendación. Puedes continuar manualmente.',
      );
    }
  }
}

class AiEntityException implements Exception {
  const AiEntityException(this.message);

  final String message;

  @override
  String toString() => message;
}
