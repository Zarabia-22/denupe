// Modelos de datos de DenuPe.

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

class Complaint {
  Complaint({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.title,
    required this.description,
    this.address,
    this.latitude,
    this.longitude,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final String title;
  final String description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return Complaint(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      categoryId: json['category_id']?.toString(),
      title: _str(json, 'title'),
      description: _str(json, 'description'),
      address: json['address'] as String?,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      status: _str(json, 'status'),
      priority: _str(json, 'priority'),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
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