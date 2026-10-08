import 'package:flutter_test/flutter_test.dart';

import 'package:denupe/models.dart';

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

    test('statusLabel traduce los estados', () {
      expect(statusLabel('en_revision'), 'En revisión');
      expect(statusLabel('desconocido'), 'desconocido');
    });
  });
}