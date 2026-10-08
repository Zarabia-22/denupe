import 'package:socket_io_client/socket_io_client.dart' as io;

/// Cambio de estado publicado por el backend en el canal `complaint:<id>`.
class StatusChangedEvent {
  StatusChangedEvent({
    required this.complaintId,
    required this.status,
    this.updatedAt,
  });

  final String complaintId;
  final String status;
  final DateTime? updatedAt;
}

/// Cliente realtime sobre socket.io.
///
/// Protocolo InsForge: socket.io sobre la base URL con `auth.token`, suscripción
/// con el evento `realtime:subscribe` y payload `{channel}`. El backend publica
/// cambios de estado como un evento socket `status_changed` (el trigger
/// `realtime_complaint_status_change` envía `{id, status, updated_at}`).
class ComplaintRealtime {
  ComplaintRealtime(this._baseUrl);

  final String _baseUrl;
  io.Socket? _socket;
  final Map<String, List<void Function(StatusChangedEvent)>> _listeners = {};
  bool _listening = false;

  void connect({required String token}) {
    if (_socket != null) return;
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    _socket!.onConnect((_) {
      for (final complaintId in _listeners.keys) {
        _sendSubscribe(complaintId);
      }
    });
    listen();
  }

  void _sendSubscribe(String complaintId) {
    _socket?.emit('realtime:subscribe', {'channel': 'complaint:$complaintId'});
  }

  void listen() {
    if (_listening) return;
    _listening = true;
    _socket?.onAny((event, payload) {
      if (event != 'status_changed') return;
      final message = _asMap(payload);
      final data = _asMap(message['data']);
      final meta = _asMap(message['meta']);

      var complaintId = data['id']?.toString() ?? '';
      final channel = meta['channel']?.toString() ??
          message['channel']?.toString() ??
          '';
      if (complaintId.isEmpty && channel.contains('complaint:')) {
        complaintId = channel
            .split('complaint:')
            .last
            .replaceAll('realtime:', '');
      }

      final status = data['status']?.toString() ?? message['status']?.toString();
      if (complaintId.isEmpty || status == null) return;

      final eventData = StatusChangedEvent(
        complaintId: complaintId,
        status: status,
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      );
      for (final listener in _listeners[complaintId] ?? const <dynamic>[]) {
        listener(eventData);
      }
    });
  }

  void subscribeComplaint(
    String complaintId,
    void Function(StatusChangedEvent event) listener,
  ) {
    final listeners = _listeners.putIfAbsent(complaintId, () => []);
    listeners.add(listener);
    if (_socket?.connected ?? false) {
      _sendSubscribe(complaintId);
    }
  }

  void unsubscribeComplaint(String complaintId) {
    _listeners[complaintId]?.clear();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _listeners.clear();
    _listening = false;
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}