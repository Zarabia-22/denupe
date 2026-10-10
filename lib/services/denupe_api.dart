import 'dart:typed_data';

import 'package:insforge_flutter/insforge_flutter.dart' hide Profile;

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

  // ------------------------------------------------------------- authorities

  Future<List<Authority>> authorities() async {
    final rows = await _client.database
        .from('autoridades')
        .select('id,nombre,sigla,tipo,descripcion,is_active')
        .eq('is_active', true)
        .order('nombre')
        .execute();
    return rows.map(Authority.fromJson).toList();
  }

  // ---------------------------------------------------------------- profile

  Future<Profile> myProfile() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client.database
        .from('perfiles')
        .select('id,full_name,dni,phone,district,role,autoridad_id,created_at')
        .eq('id', userId)
        .execute();
    if (rows.isEmpty) {
      throw InsforgeException('Perfil no encontrado');
    }
    return Profile.fromJson(rows.first);
  }

  /// Actualiza los datos editables del perfil propio (RPC acotado:
  /// solo toca full_name, dni, phone y district; nunca el rol ni la entidad).
  Future<void> updateProfile({
    required String fullName,
    String? dni,
    String? phone,
    String? district,
  }) async {
    await _client.database
        .rpc('actualizar_perfil', args: {
          'p_full_name': fullName,
          'p_dni': dni,
          'p_phone': phone,
          'p_district': district,
        })
        .execute();
  }

  // ------------------------------------------------------ panel municipal

  /// Denuncias asignadas a la entidad del funcionario autenticado.
  Future<List<Complaint>> authorityComplaints() async {
    final profile = await myProfile();
    final autoridadId = profile.autoridadId;
    if (autoridadId == null) return const [];
    final rows = await _client.database
        .from('denuncias')
        .select(
            'id,user_id,category_id,autoridad_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at,denunciante_nombre,denunciante_dni,denunciante_email,denunciante_telefono')
        .eq('autoridad_id', autoridadId)
        .order('created_at', ascending: false)
        .execute();
    return rows.map(Complaint.fromJson).toList();
  }

  /// Actualiza el estado de una denuncia (admin o entidad responsable).
  Future<void> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    String? note,
  }) async {
    await _client.database
        .rpc('update_complaint_status', args: {
          'p_complaint_id': complaintId,
          'p_new_status': newStatus,
          'p_note': note,
        })
        .execute();
  }

  // -------------------------------------------------------------- complaints

  Future<List<Complaint>> myComplaints() async {
    final rows = await _client.database
        .from('denuncias')
        .select(
            'id,user_id,category_id,autoridad_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at,denunciante_nombre,denunciante_dni,denunciante_email,denunciante_telefono')
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
    String? autoridadId,
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
          'autoridad_id': autoridadId,
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
            'id,user_id,category_id,autoridad_id,title,description,address,latitude,longitude,status,priority,created_at,updated_at,denunciante_nombre,denunciante_dni,denunciante_email,denunciante_telefono')
        .eq('id', id)
        .execute();
    if (rows.isEmpty) return null;
    return Complaint.fromJson(rows.first);
  }

  // ------------------------------------------------------------ complaint media

  static const String _mediaBucket = 'complaint-media';

  Future<List<ComplaintMedia>> complaintMedia(String complaintId) async {
    final rows = await _client.database
        .from('adjuntos_denuncia')
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
        .from('adjuntos_denuncia')
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
        .from('adjuntos_denuncia')
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