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

class ComplaintRealtime {
  ComplaintRealtime(this._api);

  final DenupeApi _api;
  Timer? _timer;
  bool _polling=false;
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

  void unsubscribeComplaint(String id,[void Function(StatusChangedEvent)? listener]){
    final list=_listeners[id];
    if(list==null)return;
    if(listener==null){_listeners.remove(id);_lastStatus.remove(id);return;}
    final index=list.indexWhere((item)=>item==listener);
    if(index>=0)list.removeAt(index);
    if(list.isEmpty){_listeners.remove(id);_lastStatus.remove(id);}
  }

  Future<void> _pollAll() async {
    if(_polling)return;
    _polling=true;
    try{
      for(final id in _listeners.keys.toList()){
        await _poll(id);
      }
    }finally{
      _polling=false;
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
            in List<void Function(StatusChangedEvent)>.from(_listeners[id] ?? const <void Function(StatusChangedEvent)>[])) {
          listener(event);
        }
      }
    } catch (_) {
      return;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
    _lastStatus.clear();
  }
}
