import 'dart:typed_data';

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
        .from('categories')
        .select('id,code,name,description')
        .order('sort_order')
        .execute();
    return rows.map(Category.fromJson).toList();
  }

  // -------------------------------------------------------------- complaints

  Future<List<Complaint>> myComplaints() async {
    final rows = await _client.database
        .from('complaints')
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
        .from('complaints')
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
        .from('complaint_status_history')
        .select('id,complaint_id,status,note,created_at')
        .eq('complaint_id', complaintId)
        .order('created_at')
        .execute();
    return rows.map(StatusHistory.fromJson).toList();
  }

  Future<Complaint?> complaintById(String id) async {
    final rows = await _client.database
        .from('complaints')
        .select(
            'id,user_id,category_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at')
        .eq('id', id)
        .execute();
    if (rows.isEmpty) return null;
    return Complaint.fromJson(rows.first);
  }

  // ------------------------------------------------------------ complaint media

  static const String _mediaBucket = 'complaint-media';

  Future<List<ComplaintMedia>> complaintMedia(String complaintId) async {
    final rows = await _client.database
        .from('complaint_media')
        .select('id,complaint_id,user_id,storage_key,url,media_type,mime_type,created_at')
        .eq('complaint_id', complaintId)
        .order('created_at', ascending: true)
        .execute();
    return rows.map(ComplaintMedia.fromJson).toList();
  }

  /// Sube el archivo al bucket privado y registra la fila en complaint_media.
  Future<ComplaintMedia> uploadComplaintMedia({
    required String complaintId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    required String mediaType,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final key = 'complaints/$complaintId/${_uniqueMediaName(filename)}';
    final stored = await _client.storage
        .from(_mediaBucket)
        .upload(key, bytes, contentType: contentType);
    final rows = await _client.database
        .from('complaint_media')
        .insert({
          'complaint_id': complaintId,
          'user_id': userId,
          'storage_key': stored.key,
          'url': stored.url,
          'media_type': mediaType,
          'mime_type': contentType,
        })
        .select()
        .execute();
    if (rows.isEmpty) {
      throw InsforgeException('No se pudo registrar el adjunto');
    }
    return ComplaintMedia.fromJson(rows.first);
  }

  /// URL firmada para descargar/mostrar el objeto (expira a los 60s).
  Future<String> complaintMediaSignedUrl(String storageKey) async {
    final strategy = await _client.storage
        .from(_mediaBucket)
        .getDownloadStrategy(storageKey);
    return strategy.url;
  }

  /// Elimina el adjunto: el objeto del bucket y su fila en la base.
  Future<void> deleteComplaintMedia(ComplaintMedia media) async {
    await _client.storage.from(_mediaBucket).delete(media.storageKey);
    await _client.database
        .from('complaint_media')
        .eq('id', media.id)
        .delete()
        .execute();
  }

  static String _uniqueMediaName(String filename) {
    final clean = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${DateTime.now().millisecondsSinceEpoch}-$clean';
  }

  // ---------------------------------------------------------- notifications

  Future<List<AppNotification>> notifications() async {
    final rows = await _client.database
        .from('notifications')
        .select('id,user_id,complaint_id,title,body,is_read,created_at')
        .order('created_at', ascending: false)
        .execute();
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.database
        .from('notifications')
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