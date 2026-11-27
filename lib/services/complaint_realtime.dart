import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Evento de cambio de estado recibido desde la API principal.
class StatusChangedEvent {
  StatusChangedEvent({required this.complaintId,required this.status,this.updatedAt});
  final String complaintId;
  final String status;
  final DateTime? updatedAt;
}

/// Realtime compatible mediante sondeo autenticado del backend. No depende del
/// protocolo propietario/socket de InsForge; consulta solo denuncias suscritas.
class ComplaintRealtime {
  ComplaintRealtime(this._baseUrl,{http.Client? client}) : _client=client??http.Client();
  final String _baseUrl;
  final http.Client _client;
  String? _token;
  Timer? _timer;
  final Map<String,List<void Function(StatusChangedEvent)>> _listeners={};
  final Map<String,String> _lastStatus={};

  void connect({required String token}) {
    _token=token;
    _timer ??= Timer.periodic(const Duration(seconds: 20),(_)=>_pollAll());
    _pollAll();
  }
  void listen() {}
  void subscribeComplaint(String id,void Function(StatusChangedEvent) listener) {
    _listeners.putIfAbsent(id,()=>[]).add(listener);
    _poll(id);
  }
  void unsubscribeComplaint(String id) { _listeners.remove(id); _lastStatus.remove(id); }
  Future<void> _pollAll() async { for(final id in _listeners.keys.toList()){await _poll(id);} }
  Future<void> _poll(String id) async {
    final token=_token;if(token==null)return;
    try {
      final uri=Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/denuncias/$id');
      final response=await _client.get(uri,headers:{'Authorization':'Bearer $token','Accept':'application/json'});
      if(response.statusCode!=200)return;
      final data=jsonDecode(response.body) as Map<String,dynamic>;
      final status=data['status']?.toString();if(status==null)return;
      final previous=_lastStatus[id];_lastStatus[id]=status;
      if(previous!=null&&previous!=status){
        final event=StatusChangedEvent(complaintId:id,status:status,updatedAt:DateTime.tryParse(data['updated_at']?.toString()??''));
        for(final listener in _listeners[id]??const <void Function(StatusChangedEvent)>[]){listener(event);}
      }
    } catch (_) {}
  }
  void dispose(){_timer?.cancel();_timer=null;_listeners.clear();_lastStatus.clear();_token=null;}
}
