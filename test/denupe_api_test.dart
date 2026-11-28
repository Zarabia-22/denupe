import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:denupe/models.dart';
import 'package:denupe/services/complaint_realtime.dart';
import 'package:denupe/services/denupe_api.dart';
import 'package:denupe/services/friendly_error.dart';

http.Response _jsonResponse(Object body, [int statusCode = 200]) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

class _StatusListener {
  final List<String> statuses = [];

  void call(StatusChangedEvent event) => statuses.add(event.status);
}

Map<String, dynamic> _complaintPayload(String status) => {
      'id': 'c1',
      'user_id': 'u1',
      'title': 'Bache',
      'description': 'Hueco',
      'status': status,
      'priority': 'alta',
      'created_at': '2026-10-07T10:00:00Z',
      'updated_at': '2026-10-07T10:00:00Z',
    };

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'DENUPE_API_URL=https://api.example.test',
    );
  });

  DenupeApi buildApi(http.Client client, [Map<String, String>? storage]) {
    final memoryStorage = _MemorySecureStorage(storage ?? <String, String>{});
    return DenupeApi(client: client, secureStorage: memoryStorage);
  }

  group('DenupeApi', () {
    test('renueva una sola vez el refresh y reintenta las peticiones', () async {
      final requests = <String>[];
      var refreshCount = 0;
      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse({
            'access_token': 'old-access',
            'refresh_token': 'old-refresh',
            'user': {'id': 'u1', 'email': 'user@example.test'},
          });
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _jsonResponse({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'user': {'id': 'u1', 'email': 'user@example.test'},
          });
        }
        if (request.url.path.endsWith('/auth/me')) {
          if (request.headers['Authorization'] != 'Bearer new-access') {
            return _jsonResponse({'detail': 'not_authenticated'}, 401);
          }
          return _jsonResponse({
            'id': 'u1',
            'email': 'user@example.test',
            'profile': {'role': 'ciudadano', 'full_name': 'Usuario'},
          });
        }
        return _jsonResponse({});
      });
      final storage = <String, String>{};
      final api = buildApi(client, storage);

      await api.signIn(email: 'user@example.test', password: 'secret');
      final profiles = await Future.wait([api.myProfile(), api.myProfile()]);

      expect(refreshCount, 1);
      expect(profiles.map((p) => p.id), ['u1', 'u1']);
      expect(storage['denupe_access_token'], 'new-access');
      expect(storage['denupe_refresh_token'], 'new-refresh');
      expect(
        requests.where((r) => r == 'POST /api/v1/auth/refresh').length,
        1,
      );
    });

    test('conserva los tokens si falla la red durante el refresh', () async {
      final storage = <String, String>{};
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse({
            'access_token': 'old-access',
            'refresh_token': 'old-refresh',
            'user': {'id': 'u1', 'email': 'user@example.test'},
          });
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          throw const SocketException('offline');
        }
        return _jsonResponse({'detail': 'not_authenticated'}, 401);
      });
      final api = buildApi(client, storage);
      await api.signIn(email: 'user@example.test', password: 'secret');

      await expectLater(api.myProfile(), throwsA(isA<DenupeApiException>()));

      expect(api.isAuthenticated, isTrue);
      expect(storage['denupe_access_token'], 'old-access');
      expect(storage['denupe_refresh_token'], 'old-refresh');
    });

    test('signUp conserva tokens cuando el backend los devuelve', () async {
      final storage = <String, String>{};
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/register');
        return _jsonResponse({
          'access_token': 'signup-access',
          'refresh_token': 'signup-refresh',
          'user': {'id': 'u2', 'email': 'new@example.test'},
        });
      });
      final api = buildApi(client, storage);

      final result = await api.signUp(
        email: 'new@example.test',
        password: 'secret',
      );

      expect(result.requireEmailVerification, isFalse);
      expect(api.isAuthenticated, isTrue);
      expect(storage['denupe_access_token'], 'signup-access');
    });

    test('exchangePasswordResetCode valida el token devuelto', () async {
      final emptyClient = MockClient(
        (_) async => _jsonResponse({'message': 'ok'}),
      );
      final emptyApi = buildApi(emptyClient);
      await expectLater(
        emptyApi.exchangePasswordResetCode(
          email: 'user@example.test',
          code: '123456',
        ),
        throwsA(isA<DenupeApiException>()),
      );

      final validClient = MockClient(
        (_) async => _jsonResponse({'token': ' reset-token '}),
      );
      final validApi = buildApi(validClient);
      expect(
        await validApi.exchangePasswordResetCode(
          email: 'user@example.test',
          code: '123456',
        ),
        'reset-token',
      );
    });

    test('uploadComplaintMedia rechaza respuestas sin storage_key', () async {
      var uploads = 0;
      final client = MockClient((request) async {
        if (request.method == 'PUT') uploads++;
        return _jsonResponse({'upload_url': 'https://r2.example.test/upload'});
      });
      final api = buildApi(client);

      await expectLater(
        api.uploadComplaintMedia(
          complaintId: 'c1',
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'foto.jpg',
          contentType: 'image/jpeg',
          mediaType: 'image',
        ),
        throwsA(isA<DenupeApiException>()),
      );
      expect(uploads, 0);
    });

    test('uploadComplaintMedia confirma la evidencia sin guardar la URL firmada',
        () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/upload-url')) {
          return _jsonResponse({
            'upload_url': 'https://r2.example.test/upload',
            'headers': {'x-test': 'value'},
            'storage_key': 'c1/evidencia.jpg',
          });
        }
        if (request.method == 'PUT') {
          expect(request.bodyBytes, [1, 2, 3]);
          expect(request.headers['x-test'], 'value');
          return http.Response('', 200);
        }
        return _jsonResponse({
          'id': 'm1',
          'storage_key': 'c1/evidencia.jpg',
          'media_type': 'image',
          'mime_type': 'image/jpeg',
          'created_at': '2026-10-07T10:00:00Z',
        });
      });
      final api = buildApi(client);

      final media = await api.uploadComplaintMedia(
        complaintId: 'c1',
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'evidencia.jpg',
        contentType: 'image/jpeg',
        mediaType: 'image',
      );

      expect(media.storageKey, 'c1/evidencia.jpg');
      expect(media.url, '');
      expect(media.complaintId, 'c1');
    });

    test('myComplaints recorre todas las páginas sin duplicados', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final offset = request.url.queryParameters['offset'];
        if (offset == '0') {
          return _jsonResponse({
            'data': [
              _complaintPayload('recibida'),
              {..._complaintPayload('recibida'), 'id': 'c2'},
            ],
            'total': 3,
          });
        }
        expect(offset, '2');
        return _jsonResponse({
          'data': [
            {..._complaintPayload('recibida'), 'id': 'c3'},
          ],
          'total': 3,
        });
      });
      final api = buildApi(client);

      final complaints = await api.myComplaints(limit: 2);

      expect(complaints.map((c) => c.id), ['c1', 'c2', 'c3']);
      expect(calls, 2);
    });

    test('myComplaints avanza el offset solo con filas nuevas', () async {
      final offsets = <String?>[];
      final client = MockClient((request) async {
        final offset = request.url.queryParameters['offset'];
        offsets.add(offset);
        switch (offset) {
          case '0':
            return _jsonResponse({
              'data': [
                _complaintPayload('recibida'),
                {..._complaintPayload('recibida'), 'id': 'c2'},
              ],
              'total': 4,
            });
          case '2':
            return _jsonResponse({
              'data': [
                {..._complaintPayload('recibida'), 'id': 'c2'},
                {..._complaintPayload('recibida'), 'id': 'c3'},
              ],
              'total': 4,
            });
          default:
            expect(offset, '3');
            return _jsonResponse({
              'data': [
                {..._complaintPayload('recibida'), 'id': 'c4'},
              ],
              'total': 4,
            });
        }
      });
      final api = buildApi(client);

      final complaints = await api.myComplaints(limit: 2);

      expect(complaints.map((c) => c.id), ['c1', 'c2', 'c3', 'c4']);
      expect(offsets, ['0', '2', '3']);
    });

    test('myComplaints supera las 1000 filas', () async {
      final client = MockClient((request) async {
        final offset = int.parse(request.url.queryParameters['offset']!);
        final limit = int.parse(request.url.queryParameters['limit']!);
        final count = (1001 - offset) < limit ? 1001 - offset : limit;
        return _jsonResponse({
          'data': List.generate(
            count,
            (i) => {
              ..._complaintPayload('recibida'),
              'id': 'c${offset + i}',
            },
          ),
          'total': 1001,
        });
      });
      final api = buildApi(client);

      final complaints = await api.myComplaints();

      expect(complaints.length, 1001);
    });

    test('markAllNotificationsRead continúa aunque falle una notificación',
        () async {
      final marked = <String>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {
                'id': 'n1',
                'user_id': 'u1',
                'title': 'Aviso 1',
                'is_read': false,
                'created_at': '2026-10-07T10:00:00Z',
              },
              {
                'id': 'n2',
                'user_id': 'u1',
                'title': 'Aviso 2',
                'is_read': false,
                'created_at': '2026-10-07T10:00:00Z',
              },
            ],
          });
        }
        final id = request.url.path.split('/').skip(4).take(1).first;
        marked.add(id);
        if (id == 'n1') return _jsonResponse({'detail': 'error'}, 500);
        return _jsonResponse({});
      });
      final api = buildApi(client);

      final failed = await api.markAllNotificationsRead();

      expect(marked, ['n1', 'n2']);
      expect(failed, ['n1']);
    });

    test('complaintMediaSignedUrl cachea y renueva la URL prefirmada', () async {
      var downloadUrlCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/download-url')) {
          downloadUrlCalls++;
          return _jsonResponse({'download_url': 'https://r2.example.test/firma'});
        }
        return _jsonResponse({
          'data': [
            {
              'id': 'm1',
              'storage_key': 'c1/foto.jpg',
              'media_type': 'image',
              'created_at': '2026-10-07T10:00:00Z',
            },
          ],
        });
      });
      final api = buildApi(client);

      final first = await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
      );
      final cached = await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
      );
      await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
        refresh: true,
      );

      expect(first, 'https://r2.example.test/firma');
      expect(cached, first);
      expect(downloadUrlCalls, 2);
    });

    test('complaintMediaSignedUrl aplica forceRefresh a la caché', () async {
      var downloadUrlCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/download-url')) {
          downloadUrlCalls++;
          return _jsonResponse({
            'download_url': 'https://r2.example.test/firma-$downloadUrlCalls',
            'expires_in': 300,
          });
        }
        return _jsonResponse({
          'data': [
            {
              'id': 'm1',
              'storage_key': 'c1/foto.jpg',
              'media_type': 'image',
              'created_at': '2026-10-07T10:00:00Z',
            },
          ],
        });
      });
      final api = buildApi(client);

      final first = await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
      );
      final cached = await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
      );
      final refreshed = await api.complaintMediaSignedUrl(
        'c1/foto.jpg',
        complaintId: 'c1',
        forceRefresh: true,
      );

      expect(first, 'https://r2.example.test/firma-1');
      expect(cached, first);
      expect(refreshed, 'https://r2.example.test/firma-2');
      expect(downloadUrlCalls, 2);
    });

    test('complaintMediaSignedUrl respeta expires_in del backend', () async {
      var downloadUrlCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/download-url')) {
          downloadUrlCalls++;
          return _jsonResponse({
            'download_url': 'https://r2.example.test/firma-$downloadUrlCalls',
            'expires_in': 1,
          });
        }
        return _jsonResponse({
          'data': [
            {
              'id': 'm1',
              'storage_key': 'c1/foto.jpg',
              'media_type': 'image',
              'created_at': '2026-10-07T10:00:00Z',
            },
          ],
        });
      });
      final api = buildApi(client);

      await api.complaintMediaSignedUrl('c1/foto.jpg', complaintId: 'c1');
      await api.complaintMediaSignedUrl('c1/foto.jpg', complaintId: 'c1');
      expect(downloadUrlCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await api.complaintMediaSignedUrl('c1/foto.jpg', complaintId: 'c1');
      expect(downloadUrlCalls, 2);
    });

    test('complaintMediaSignedUrl respeta expires_at del backend', () async {
      var downloadUrlCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/download-url')) {
          downloadUrlCalls++;
          return _jsonResponse({
            'download_url': 'https://r2.example.test/firma-$downloadUrlCalls',
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          });
        }
        return _jsonResponse({
          'data': [
            {
              'id': 'm1',
              'storage_key': 'c1/foto.jpg',
              'media_type': 'image',
              'created_at': '2026-10-07T10:00:00Z',
            },
          ],
        });
      });
      final api = buildApi(client);

      await api.complaintMediaSignedUrl('c1/foto.jpg', complaintId: 'c1');
      await api.complaintMediaSignedUrl('c1/foto.jpg', complaintId: 'c1');
      expect(downloadUrlCalls, 2);
    });

    test('rechaza URLs prefirmadas inseguras antes de enviar bytes', () async {
      var uploads = 0;
      final client = MockClient((request) async {
        if (request.method == 'PUT') uploads++;
        return _jsonResponse({
          'upload_url': 'http://user:pass@r2.example.test/upload',
          'headers': {'x-test': 'value'},
          'storage_key': 'c1/evidencia.jpg',
        });
      });
      final api = buildApi(client);

      await expectLater(
        api.uploadComplaintMedia(
          complaintId: 'c1',
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'evidencia.jpg',
          contentType: 'image/jpeg',
          mediaType: 'image',
        ),
        throwsA(isA<DenupeApiException>()),
      );
      expect(uploads, 0);
    });

    test('currentUser se conserva aunque /auth/me no devuelva email', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse({
            'access_token': 'token',
            'refresh_token': 'refresh',
            'user': {'id': 'u1'},
          });
        }
        return _jsonResponse({'id': 'u1'});
      });
      final api = buildApi(client);

      await api.signIn(email: 'user@example.test', password: 'secret');
      expect(api.currentUser?.id, 'u1');
      await api.initialize();
      expect(api.currentUser?.id, 'u1');
    });
  });

  group('statusTransitions', () {
    test('define transiciones permitidas y estados terminales', () {
      expect(
        statusTransitions['recibida'],
        containsAll(['en_revision', 'rechazada', 'archivada']),
      );
      expect(statusTransitions['recibida']!.length, 3);
      expect(
        statusTransitions['en_revision'],
        containsAll(['en_proceso', 'rechazada', 'archivada']),
      );
      expect(statusTransitions['en_revision']!.length, 3);
      expect(
        statusTransitions['en_proceso'],
        containsAll(['resuelta', 'rechazada', 'archivada']),
      );
      expect(statusTransitions['en_proceso']!.length, 3);
      for (final status in ['resuelta', 'rechazada', 'archivada']) {
        expect(statusTransitions[status], isEmpty);
      }
      expect(canTransitionStatus('recibida', 'en_proceso'), isFalse);
      expect(canTransitionStatus('en_revision', 'resuelta'), isFalse);
      expect(canTransitionStatus('en_proceso', 'resuelta'), isTrue);
    });
  });

  group('ComplaintRealtime', () {
    test('unsubscribeComplaint conserva los demás listeners', () async {
      final statuses = ['recibida', 'recibida', 'en_proceso', 'resuelta'];
      var index = 0;
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/denuncias/c1');
        final status = statuses[index++];
        return _jsonResponse(_complaintPayload(status));
      });
      final api = buildApi(client);
      final realtime = ComplaintRealtime(api);
      final first = _StatusListener();
      final second = _StatusListener();

      realtime.subscribeComplaint('c1', first.call);
      realtime.subscribeComplaint('c1', second.call);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      realtime.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      realtime.unsubscribeComplaint('c1', first.call);
      realtime.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(first.statuses, ['en_proceso']);
      expect(second.statuses, ['en_proceso', 'resuelta']);
      expect(index, statuses.length);
      realtime.dispose();
    });
  });

  group('friendlyError', () {
    test('expone mensajes seguros del backend y oculta detalles internos', () {
      expect(
        friendlyError(DenupeApiException('Correo o contraseña incorrectos.')),
        'Correo o contraseña incorrectos.',
      );
      expect(
        friendlyError(DenupeApiException('estado_no_permitido')),
        'estado_no_permitido',
      );
      expect(
        friendlyError(const SocketException('10.0.0.1:5432 password=secret')),
        'No se pudo completar la operación. Inténtalo de nuevo.',
      );
    });
  });
}
