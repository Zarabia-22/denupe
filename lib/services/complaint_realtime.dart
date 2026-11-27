import 'dart:async';

import 'denupe_api.dart';

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

/// Seguimiento de cambios mediante sondeo autenticado del backend REST.
/// Reutiliza DenupeApi para aprovechar la renovación de tokens JWT.
class ComplaintRealtime {
  ComplaintRealtime(this._api);

  final DenupeApi _api;
  Timer? _timer;
  final Map<String, List<void Function(StatusChangedEvent)>> _listeners = {};
  final Map<String, String> _lastStatus = {};

  void connect() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pollAll(),
    );
    _pollAll();
  }

  void subscribeComplaint(
    String id,
    void Function(StatusChangedEvent) listener,
  ) {
    _listeners.putIfAbsent(id, () => []).add(listener);
    _poll(id);
  }

  void unsubscribeComplaint(String id) {
    _listeners.remove(id);
    _lastStatus.remove(id);
  }

  Future<void> _pollAll() async {
    for (final id in _listeners.keys.toList()) {
      await _poll(id);
    }
  }

  Future<void> _poll(String id) async {
    try {
      final complaint = await _api.complaintById(id);
      if (complaint == null) return;

      final previous = _lastStatus[id];
      _lastStatus[id] = complaint.status;
      if (previous != null && previous != complaint.status) {
        final event = StatusChangedEvent(
          complaintId: id,
          status: complaint.status,
          updatedAt: complaint.updatedAt,
        );
        for (final listener
            in _listeners[id] ?? const <void Function(StatusChangedEvent)>[]) {
          listener(event);
        }
      }
    } catch (_) {
      // El sondeo siguiente reintentará sin interrumpir la interfaz.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
    _lastStatus.clear();
  }
}
