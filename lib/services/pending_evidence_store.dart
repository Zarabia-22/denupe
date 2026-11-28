import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// Persiste evidencias pendientes en el directorio privado de la aplicación.
/// Los archivos quedan separados por usuario y denuncia.
class PendingEvidenceStore {
  PendingEvidenceStore({Future<Directory> Function()? rootDirectory})
      : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _rootDirectory;

  Future<Directory> _complaintDirectory(String userId, String complaintId) async {
    final root = await _rootDirectory();
    final user = _safeSegment(userId);
    final complaint = _safeSegment(complaintId);
    return Directory('${root.path}/pending_evidence/$user/$complaint');
  }

  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw ArgumentError.value(value, 'identifier', 'Identificador no válido');
    }
    return safe;
  }

  Future<File> _manifest(Directory directory) async =>
      File('${directory.path}/manifest.json');

  /// Guarda todo el lote antes de iniciar cualquier transferencia de red.
  Future<void> saveBatch({
    required String userId,
    required String complaintId,
    required List<ComplaintAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return;
    final directory = await _complaintDirectory(userId, complaintId);
    await directory.create(recursive: true);
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < attachments.length; i++) {
      final item = attachments[i];
      final filename = 'evidence_$i.bin';
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(item.bytes, flush: true);
      entries.add({
        'file': filename,
        'name': item.name,
        'media_type': item.mediaType,
        'content_type': item.contentType,
      });
    }
    final manifest = await _manifest(directory);
    final temporary = File('${manifest.path}.tmp');
    await temporary.writeAsString(jsonEncode({
      'version': 1,
      'user_id': userId,
      'complaint_id': complaintId,
      'attachments': entries,
    }), flush: true);
    await temporary.rename(manifest.path);
  }

  /// Recupera únicamente archivos pertenecientes al usuario autenticado.
  Future<List<PendingEvidenceBatch>> pendingForUser(String userId) async {
    final root = await _rootDirectory();
    final userDirectory = Directory('${root.path}/pending_evidence/${_safeSegment(userId)}');
    if (!await userDirectory.exists()) return [];
    final batches = <PendingEvidenceBatch>[];
    await for (final entity in userDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      try {
        final manifestFile = await _manifest(entity);
        if (!await manifestFile.exists()) continue;
        final data = jsonDecode(await manifestFile.readAsString());
        if (data is! Map || data['user_id'] != userId) continue;
        final complaintId = data['complaint_id'];
        final raw = data['attachments'];
        if (complaintId is! String || raw is! List) continue;
        final attachments = <ComplaintAttachment>[];
        final keys = <String>[];
        for (final value in raw) {
          if (value is! Map) continue;
          final filename = value['file'];
          if (filename is! String || filename != File(filename).uri.pathSegments.last) continue;
          final file = File('${entity.path}/$filename');
          if (!await file.exists()) continue;
          attachments.add(ComplaintAttachment(
            name: value['name']?.toString() ?? 'evidencia',
            mediaType: value['media_type']?.toString() ?? 'imagen',
            contentType: value['content_type']?.toString() ?? 'application/octet-stream',
            bytes: await file.readAsBytes(),
          ));
          keys.add(filename);
        }
        if (attachments.isNotEmpty) {
          batches.add(PendingEvidenceBatch(
            complaintId: complaintId,
            attachments: attachments,
            keys: keys,
          ));
        }
      } on FormatException {
        // Un manifiesto incompleto no debe impedir recuperar otros lotes.
      } on FileSystemException {
        // Un archivo inaccesible se conserva para inspección/reintento posterior.
      }
    }
    return batches;
  }

  /// Marca un archivo como subido y lo elimina del manifiesto local.
  Future<void> markUploaded({
    required String userId,
    required String complaintId,
    required String fileKey,
  }) async {
    if (fileKey != File(fileKey).uri.pathSegments.last || !fileKey.endsWith('.bin')) {
      throw ArgumentError.value(fileKey, 'fileKey');
    }
    final directory = await _complaintDirectory(userId, complaintId);
    final manifest = await _manifest(directory);
    if (!await manifest.exists()) return;
    final data = jsonDecode(await manifest.readAsString());
    if (data is! Map || data['user_id'] != userId || data['complaint_id'] != complaintId) return;
    final entries = List<Map<String, dynamic>>.from(data['attachments'] as List? ?? []);
    final removed = entries.where((entry) => entry['file'] == fileKey).toList();
    entries.removeWhere((entry) => entry['file'] == fileKey);
    for (final entry in removed) {
      final file = File('${directory.path}/${entry['file']}');
      if (await file.exists()) await file.delete();
    }
    if (entries.isEmpty) {
      await removeBatch(userId: userId, complaintId: complaintId);
      return;
    }
    final temporary = File('${manifest.path}.tmp');
    await temporary.writeAsString(jsonEncode({...data, 'attachments': entries}), flush: true);
    await temporary.rename(manifest.path);
  }

  /// Elimina el lote solo después de confirmar todas las subidas.
  Future<void> removeBatch({
    required String userId,
    required String complaintId,
  }) async {
    final directory = await _complaintDirectory(userId, complaintId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

class PendingEvidenceBatch {
  const PendingEvidenceBatch({
    required this.complaintId,
    required this.attachments,
    required this.keys,
  });

  final String complaintId;
  final List<ComplaintAttachment> attachments;
  final List<String> keys;
}
