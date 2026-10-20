import 'package:insforge_flutter/insforge_flutter.dart';

import '../models.dart';

/// Acceso a datos del backend InsForge (vía `@insforge/sdk` Dart).
class DenupeApi {
  DenupeApi(this._client);

  final InsforgeClient _client;

  InsforgeClient get client => _client;

  // ------------------------------------------------------------------ auth

  Future<SignUpResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) =>
      _client.auth.signUp(email: email, password: password, name: name);

  Future<void> sendVerificationEmail(String email) =>
      _client.auth.sendVerificationEmail(email);

  Future<void> verifyEmail({String? email, required String otp}) =>
      _client.auth.verifyEmail(email: email, otp: otp);

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signIn(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  String? get accessToken => _client.auth.currentSession?.accessToken;

  // -------------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    final rows = await _client.database
        .from('categorias')
        .select('id,code,name,description')
        .order('sort_order')
        .execute();
    return rows.map(Category.fromJson).toList();
  }

  // -------------------------------------------------------------- complaints

  Future<List<Complaint>> myComplaints() async {
    final rows = await _client.database
        .from('denuncias')
        .select(
            'id,user_id,category_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at')
        .order('created_at', ascending: false)
        .execute();
    return rows.map(Complaint.fromJson).toList();
  }

  Future<Complaint> createComplaint({
    required String categoryId,
    required String title,
    required String description,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client.database
        .from('denuncias')
        .insert({
          'user_id': userId,
          'category_id': categoryId,
          'title': title,
          'description': description,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select()
        .execute();
    if (rows.isEmpty) {
      throw InsforgeException('No se pudo crear la denuncia');
    }
    return Complaint.fromJson(rows.first);
  }

  Future<List<StatusHistory>> complaintHistory(String complaintId) async {
    final rows = await _client.database
        .from('historial_estados')
        .select('id,complaint_id,status,note,created_at')
        .eq('complaint_id', complaintId)
        .order('created_at')
        .execute();
    return rows.map(StatusHistory.fromJson).toList();
  }

  Future<Complaint?> complaintById(String id) async {
    final rows = await _client.database
        .from('denuncias')
        .select(
            'id,user_id,category_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at')
        .eq('id', id)
        .execute();
    if (rows.isEmpty) return null;
    return Complaint.fromJson(rows.first);
  }

  // ---------------------------------------------------------- notifications

  Future<List<AppNotification>> notifications() async {
    final rows = await _client.database
        .from('notificaciones')
        .select('id,user_id,complaint_id,title,body,is_read,created_at')
        .order('created_at', ascending: false)
        .execute();
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.database
        .from('notificaciones')
        .eq('id', id)
        .update({'is_read': true})
        .execute();
  }

  Future<void> markAllNotificationsRead() async {
    final items = await notifications();
    for (final n in items.where((n) => !n.isRead)) {
      await markNotificationRead(n.id);
    }
  }

  Future<int> unreadNotificationsCount() async {
    final items = await notifications();
    return items.where((n) => !n.isRead).length;
  }
}