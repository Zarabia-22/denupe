// Modelos de datos de DenuPe.

import 'dart:typed_data';

DateTime _parseDate(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  if (value is DateTime) return value.toLocal();
  throw const FormatException('Fecha inválida');
}

String _str(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return '';
  return v.toString();
}

class Category {
  Category({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'].toString(),
        code: json['code'].toString(),
        name: json['name'].toString(),
        description: json['description'] as String?,
      );
}

class Authority {
  Authority({
    required this.id,
    required this.nombre,
    required this.sigla,
    required this.tipo,
    this.descripcion,
    required this.isActive,
  });

  final String id;
  final String nombre;
  final String sigla;
  final String tipo;
  final String? descripcion;
  final bool isActive;

  factory Authority.fromJson(Map<String, dynamic> json) => Authority(
        id: json['id'].toString(),
        nombre: _str(json, 'nombre'),
        sigla: _str(json, 'sigla'),
        tipo: _str(json, 'tipo'),
        descripcion: json['descripcion'] as String?,
        isActive: json['is_active'] == true,
      );
}

class Profile {
  Profile({
    required this.id,
    this.fullName,
    this.dni,
    this.phone,
    this.district,
    required this.role,
    this.autoridadId,
    this.createdAt,
  });

  final String id;
  final String? fullName;
  final String? dni;
  final String? phone;
  final String? district;
  final String role;
  final String? autoridadId;
  final DateTime? createdAt;

  bool get isFuncionario => role == 'funcionario';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'].toString(),
        fullName: json['full_name'] as String?,
        dni: json['dni'] as String?,
        phone: json['phone'] as String?,
        district: json['district'] as String?,
        role: _str(json, 'role'),
        autoridadId: json['autoridad_id']?.toString(),
        createdAt:
            json['created_at'] != null ? _parseDate(json['created_at']) : null,
      );
}

class Complaint {
  Complaint({
    required this.id,
    required this.userId,
    this.categoryId,
    this.autoridadId,
    required this.title,
    required this.description,
    this.address,
    this.latitude,
    this.longitude,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.denuncianteNombre,
    this.denuncianteDni,
    this.denuncianteEmail,
    this.denuncianteTelefono,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final String? autoridadId;
  final String title;
  final String description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? denuncianteNombre;
  final String? denuncianteDni;
  final String? denuncianteEmail;
  final String? denuncianteTelefono;

  bool get hasDenuncianteData =>
      (denuncianteNombre?.trim().isNotEmpty ?? false) ||
      (denuncianteDni?.trim().isNotEmpty ?? false) ||
      (denuncianteEmail?.trim().isNotEmpty ?? false) ||
      (denuncianteTelefono?.trim().isNotEmpty ?? false);

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return Complaint(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      categoryId: json['category_id']?.toString(),
      autoridadId: json['autoridad_id']?.toString(),
      title: _str(json, 'title'),
      description: _str(json, 'description'),
      address: json['address'] as String?,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      status: _str(json, 'status'),
      priority: _str(json, 'priority'),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      denuncianteNombre: json['denunciante_nombre'] as String?,
      denuncianteDni: json['denunciante_dni'] as String?,
      denuncianteEmail: json['denunciante_email'] as String?,
      denuncianteTelefono: json['denunciante_telefono'] as String?,
    );
  }
}

class ComplaintMedia {
  ComplaintMedia({
    required this.id,
    required this.complaintId,
    required this.userId,
    required this.storageKey,
    required this.url,
    required this.mediaType,
    this.mimeType,
    required this.createdAt,
  });

  final String id;
  final String complaintId;
  final String userId;
  final String storageKey;
  final String url;
  final String mediaType;
  final String? mimeType;
  final DateTime createdAt;

  bool get isImage => mediaType == 'image';

  factory ComplaintMedia.fromJson(Map<String, dynamic> json) =>
      ComplaintMedia(
        id: json['id'].toString(),
        complaintId: json['complaint_id'].toString(),
        userId: json['user_id'].toString(),
        storageKey: _str(json, 'storage_key'),
        url: _str(json, 'url'),
        mediaType: _str(json, 'media_type'),
        mimeType: json['mime_type'] as String?,
        createdAt: _parseDate(json['created_at']),
      );
}

class StatusHistory {
  StatusHistory({
    required this.id,
    required this.complaintId,
    required this.status,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String complaintId;
  final String status;
  final String? note;
  final DateTime createdAt;

  factory StatusHistory.fromJson(Map<String, dynamic> json) => StatusHistory(
        id: json['id'].toString(),
        complaintId: json['complaint_id'].toString(),
        status: _str(json, 'status'),
        note: json['note'] as String?,
        createdAt: _parseDate(json['created_at']),
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    this.complaintId,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? complaintId;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'].toString(),
        userId: json['user_id'].toString(),
        complaintId: json['complaint_id']?.toString(),
        title: _str(json, 'title'),
        body: json['body'] as String?,
        isRead: json['is_read'] == true,
        createdAt: _parseDate(json['created_at']),
      );
}

/// Labels en español para cada estado de la denuncia.
const Map<String, String> statusLabels = {
  'recibida': 'Recibida',
  'en_revision': 'En revisión',
  'en_proceso': 'En proceso',
  'resuelta': 'Resuelta',
  'rechazada': 'Rechazada',
  'archivada': 'Archivada',
};

String statusLabel(String status) => statusLabels[status] ?? status;

/// Adjunto pendiente de subir junto con la denuncia.
class ComplaintAttachment {
  const ComplaintAttachment({
    required this.name,
    required this.mediaType,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final String mediaType;
  final Uint8List bytes;
  final String contentType;
}