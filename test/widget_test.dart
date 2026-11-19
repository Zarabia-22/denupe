import 'package:flutter_test/flutter_test.dart';

import 'package:denupe/models.dart';
import 'package:denupe/services/ai_category_service.dart';
import 'package:denupe/services/ai_entity_service.dart';

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

}
