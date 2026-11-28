import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:denupe/models.dart';
import 'package:denupe/services/ai_category_service.dart';
import 'package:denupe/services/ai_entity_service.dart';
import 'package:denupe/services/entity_display_name.dart';

void main() {
  group('models', () {
    test('Complaint.fromJson parsea los campos', () {
      final complaint = Complaint.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'category_id': 'cat-1',
        'title': 'Bache en la avenida',
        'description': 'Hueco grande',
        'address': 'Av. Central 123',
        'latitude': -12.123456,
        'longitude': -77.123456,
        'status': 'recibida',
        'priority': 'alta',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
      });

      expect(complaint.id, 'c1');
      expect(complaint.categoryId, 'cat-1');
      expect(complaint.latitude, -12.123456);
      expect(complaint.status, 'recibida');
      expect(complaint.autoridadId, isNull);
    });

    test('Complaint.fromJson parsea autoridad_id', () {
      final complaint = Complaint.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'category_id': 'cat-1',
        'autoridad_id': 'aut-1',
        'title': 'Título',
        'description': 'Descripción',
        'status': 'recibida',
        'priority': 'media',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
      });

      expect(complaint.autoridadId, 'aut-1');
    });

    test('Complaint.fromJson parsea los datos del denunciante', () {
      final complaint = Complaint.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'category_id': 'cat-1',
        'title': 'Título',
        'description': 'Descripción',
        'status': 'recibida',
        'priority': 'normal',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
        'denunciante_nombre': 'Ana Ciudadana',
        'denunciante_dni': '12345678',
        'denunciante_email': 'ana@ejemplo.com',
        'denunciante_telefono': '999888777',
      });

      expect(complaint.denuncianteNombre, 'Ana Ciudadana');
      expect(complaint.denuncianteDni, '12345678');
      expect(complaint.denuncianteEmail, 'ana@ejemplo.com');
      expect(complaint.denuncianteTelefono, '999888777');
      expect(complaint.hasDenuncianteData, isTrue);
    });

    test('Complaint.hasDenuncianteData es falso sin datos', () {
      final complaint = Complaint.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'title': 'Título',
        'description': 'Descripción',
        'status': 'recibida',
        'priority': 'normal',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
      });

      expect(complaint.denuncianteNombre, isNull);
      expect(complaint.hasDenuncianteData, isFalse);
    });

    test('Authority.fromJson parsea las entidades receptoras', () {
      final authority = Authority.fromJson({
        'id': 'aut-1',
        'nombre': 'Municipalidad del Distrito',
        'sigla': 'MUN',
        'tipo': 'municipalidad',
        'descripcion': 'Servicios municipales',
        'is_active': true,
      });

      expect(authority.nombre, 'Municipalidad del Distrito');
      expect(authority.sigla, 'MUN');
      expect(authority.tipo, 'municipalidad');
      expect(authority.isActive, isTrue);
    });

    test('AppNotification.fromJson parsea is_read y fecha', () {
      final notification = AppNotification.fromJson({
        'id': 'n1',
        'user_id': 'u1',
        'complaint_id': 'c1',
        'title': 'Estado actualizado',
        'body': 'Pasó a En proceso',
        'is_read': false,
        'created_at': '2026-10-07T12:00:00Z',
      });

      expect(notification.isRead, isFalse);
      expect(notification.complaintId, 'c1');
    });

    test('Profile.fromJson parsea rol y entidad', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'full_name': 'Ana Funcionaria',
        'role': 'funcionario',
        'autoridad_id': 'aut-1',
      });

      expect(profile.fullName, 'Ana Funcionaria');
      expect(profile.role, 'funcionario');
      expect(profile.autoridadId, 'aut-1');
      expect(profile.isFuncionario, isTrue);

      final citizen = Profile.fromJson({
        'id': 'u2',
        'role': 'citizen',
      });

      expect(citizen.isFuncionario, isFalse);
      expect(citizen.autoridadId, isNull);
    });

    test('Profile.fromJson parsea created_at', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'full_name': 'Ana',
        'role': 'citizen',
        'created_at': '2026-10-07T12:00:00Z',
      });
      expect(profile.createdAt, isNotNull);

      final noDate = Profile.fromJson({'id': 'u2', 'role': 'citizen'});
      expect(noDate.createdAt, isNull);
    });

    test('statusLabel traduce los estados', () {
      expect(statusLabel('en_revision'), 'En revisión');
      expect(statusLabel('desconocido'), 'desconocido');
    });

    test('ComplaintMedia.fromJson parsea adjuntos y detecta tipo', () {
      final media = ComplaintMedia.fromJson({
        'id': 'm1',
        'complaint_id': 'c1',
        'user_id': 'u1',
        'storage_key': 'complaints/c1/foto.png',
        'url': 'https://example.com/foto.png',
        'media_type': 'image',
        'mime_type': 'image/png',
        'created_at': '2026-10-07T12:00:00Z',
      });

      expect(media.isImage, isTrue);
      expect(media.storageKey, 'complaints/c1/foto.png');
      expect(media.mimeType, 'image/png');

      final video = ComplaintMedia.fromJson({
        'id': 'm2',
        'complaint_id': 'c1',
        'user_id': 'u1',
        'storage_key': 'complaints/c1/video.mp4',
        'url': 'https://example.com/video.mp4',
        'media_type': 'video',
        'mime_type': 'video/mp4',
        'created_at': '2026-10-07T12:00:00Z',
      });

      expect(video.isImage, isFalse);
    });
  });

  group('contratos del servicio de IA', () {
    test('AiEntityService envía contexto territorial y procesa la sugerencia', () async {
      dotenv.loadFromString(envString: 'DENUPE_API_URL=https://api.example.test');
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/ia/sugerir-entidad');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['categoria'], 'Agua y saneamiento');
        expect(body['departamento'], 'Lima');
        expect(body['provincia'], 'Lima');
        expect(body['distrito'], 'Miraflores');
        expect(body['titulo'], 'Fuga de agua');
        expect(body['descripcion'], 'Hay una tubería rota en la vereda.');
        expect(body['latitud'], -12.12);
        expect(body['longitud'], -77.03);
        return http.Response(
          jsonEncode({
            'sugerida': true,
            'motivo': 'La incidencia corresponde a saneamiento.',
            'entidad': {
              'id': 'sedapal-lima-callao',
              'nombre': 'SEDAPAL',
              'tipo': 'empresa_saneamiento',
              'ambito': {
                'departamento': 'Lima',
                'provincia': 'Lima',
                'distrito': 'Miraflores',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final suggestion = await AiEntityService(client: client).sugerirEntidad(
        categoria: 'Agua y saneamiento',
        departamento: 'Lima',
        provincia: 'Lima',
        distrito: 'Miraflores',
        titulo: 'Fuga de agua',
        descripcion: 'Hay una tubería rota en la vereda.',
        latitud: -12.12,
        longitud: -77.03,
      );
      client.close();

      expect(suggestion.sugerida, isTrue);
      expect(suggestion.entidad?.id, 'sedapal-lima-callao');
      expect(suggestion.entidad?.tipo, 'empresa_saneamiento');
    });

    test('AiCategorySuggestion acepta la respuesta vigente del backend', () {
      final suggestion = AiCategorySuggestion.fromJson({
        'sugerida': true,
        'categoria': 'Vialidad e infraestructura',
        'confianza_modelo': 0.91,
        'cobertura_vocabulario': 0.84,
        'motivo': null,
      });

      expect(suggestion.sugerida, isTrue);
      expect(suggestion.categoria, 'Vialidad e infraestructura');
      expect(suggestion.motivo, isNull);
    });

    test('AiEntitySuggestion parsea una entidad pública especializada', () {
      final suggestion = AiEntitySuggestion.fromJson({
        'sugerida': true,
        'motivo': 'La competencia corresponde al servicio de saneamiento.',
        'entidad': {
          'id': 'sedapal-001',
          'nombre': 'SEDAPAL',
          'tipo': 'empresa_saneamiento',
          'direccion': null,
          'telefono': null,
          'sitio_web': 'https://www.sedapal.com.pe',
          'ambito': {'departamento': 'Lima', 'provincia': 'Lima'},
        },
      });

      expect(suggestion.sugerida, isTrue);
      expect(suggestion.entidad?.id, 'sedapal-001');
      expect(suggestion.entidad?.tipo, 'empresa_saneamiento');
      expect(suggestion.entidad?.ambito['provincia'], 'Lima');
    });

    test('AiEntitySuggestion reconoce revisión de competencia como destino interno', () {
      final suggestion = AiEntitySuggestion.fromJson({
        'sugerida': true,
        'motivo': 'No se pudo identificar una única institución competente.',
        'entidad': {
          'id': 'revision-competencia',
          'nombre': 'Revisión de competencia',
          'tipo': 'revision_competencia',
          'ambito': <String, dynamic>{},
        },
      });

      expect(suggestion.entidad?.tipo, 'revision_competencia');
      expect(suggestion.entidad?.ambito, isEmpty);
    });

    test('AiEntitySuggestion tolera abstención sin entidad', () {
      final suggestion = AiEntitySuggestion.fromJson({
        'sugerida': false,
        'motivo': 'No hay información territorial suficiente.',
        'entidad': null,
      });

      expect(suggestion.sugerida, isFalse);
      expect(suggestion.entidad, isNull);
      expect(suggestion.motivo, contains('territorial'));
    });
  });

  group('nombres dinámicos de entidades', () {
    test('reemplaza etiquetas genéricas por el distrito y el tipo', () {
      expect(
        entityDisplayName(
          reference: 'Municipalidad provincial o distrital competente del UBIGEO',
          type: 'municipalidad',
          district: 'Miraflores',
        ),
        'Municipalidad de Miraflores',
      );
      expect(
        entityDisplayName(
          reference: 'Empresa concesionaria de distribución eléctrica competente',
          type: 'concesionaria_electrica',
          district: 'Miraflores',
        ),
        'Empresa eléctrica de Miraflores',
      );
      expect(
        entityDisplayName(
          reference: 'Revisión de competencia',
          type: 'revision_competencia',
          district: 'Miraflores',
        ),
        'Atención territorial de Miraflores',
      );
    });

    test('conserva nombres específicos y usa un respaldo sin distrito', () {
      expect(
        entityDisplayName(
          reference: 'SEDAPAL Lima',
          type: 'empresa_saneamiento',
          district: 'Miraflores',
        ),
        'SEDAPAL Lima',
      );
      expect(
        entityDisplayName(reference: 'Entidad competente', district: ''),
        'Atención territorial',
      );
    });
  });

}
