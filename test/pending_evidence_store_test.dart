import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:denupe/models.dart';
import 'package:denupe/services/pending_evidence_store.dart';

void main() {
  late Directory root;
  late PendingEvidenceStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('denupe-evidence-test-');
    store = PendingEvidenceStore(rootDirectory: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  ComplaintAttachment attachment(String name, List<int> bytes) =>
      ComplaintAttachment(
        name: name,
        mediaType: 'imagen',
        contentType: 'image/jpeg',
        bytes: Uint8List.fromList(bytes),
      );

  test('persiste y recupera evidencias después de crear otra instancia', () async {
    await store.saveBatch(
      userId: 'user-1',
      complaintId: 'complaint-1',
      attachments: [
        attachment('foto-a.jpg', [1, 2, 3]),
        attachment('foto-b.jpg', [4, 5, 6]),
      ],
    );

    final recovered = await PendingEvidenceStore(
      rootDirectory: () async => root,
    ).pendingForUser('user-1');

    expect(recovered, hasLength(1));
    expect(recovered.single.complaintId, 'complaint-1');
    expect(recovered.single.attachments, hasLength(2));
    expect(recovered.single.attachments.first.bytes, [1, 2, 3]);
    expect(recovered.single.keys, ['evidence_0.bin', 'evidence_1.bin']);
  });

  test('aísla evidencias entre usuarios', () async {
    await store.saveBatch(
      userId: 'user-1',
      complaintId: 'complaint-1',
      attachments: [attachment('foto.jpg', [1])],
    );

    expect(await store.pendingForUser('user-2'), isEmpty);
    expect(await store.pendingForUser('user-1'), hasLength(1));
  });

  test('retira solo la evidencia confirmada y elimina el lote al finalizar', () async {
    await store.saveBatch(
      userId: 'user-1',
      complaintId: 'complaint-1',
      attachments: [
        attachment('foto-a.jpg', [1]),
        attachment('foto-b.jpg', [2]),
      ],
    );

    await store.markUploaded(
      userId: 'user-1',
      complaintId: 'complaint-1',
      fileKey: 'evidence_0.bin',
    );
    var recovered = await store.pendingForUser('user-1');
    expect(recovered.single.attachments, hasLength(1));
    expect(recovered.single.attachments.single.name, 'foto-b.jpg');
    expect(recovered.single.keys, ['evidence_1.bin']);

    await store.markUploaded(
      userId: 'user-1',
      complaintId: 'complaint-1',
      fileKey: 'evidence_1.bin',
    );
    expect(await store.pendingForUser('user-1'), isEmpty);
  });
}
