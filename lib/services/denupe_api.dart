import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

class DenupeApiException implements Exception {
  DenupeApiException(this.message,{this.statusCode,this.code});
  final String message; final int? statusCode; final String? code;
  @override String toString()=>message;
}
class DenupeUser { const DenupeUser({required this.id,this.email}); final String id; final String? email; }
class SignUpResult { const SignUpResult({required this.requireEmailVerification}); final bool requireEmailVerification; }
class _SignedUrl { const _SignedUrl(this.url,this.expiresAt); final String url; final DateTime expiresAt; }

bool _isSafeSignedUrl(String value){
  final uri=Uri.tryParse(value.trim());
  return uri!=null&&uri.scheme.toLowerCase()=='https'&&uri.host.isNotEmpty&&uri.userInfo.isEmpty;
}
DateTime _signedUrlExpiry(Map<String,dynamic> d){
  final at=d['expires_at'];
  if(at is DateTime)return at.toLocal();
  if(at is String){final parsed=DateTime.tryParse(at);if(parsed!=null)return parsed.toLocal();}
  if(at is num){final v=at.toInt();return DateTime.fromMillisecondsSinceEpoch(v>100000000000?v:v*1000);}
  final seconds=num.tryParse(d['expires_in']?.toString()??'');
  if(seconds!=null&&seconds>0)return DateTime.now().add(Duration(seconds:seconds.toInt()));
  return DateTime.now().add(DenupeApi.signedUrlTtl);
}

class DenupeApi {
  DenupeApi({http.Client? client,FlutterSecureStorage? secureStorage})
    : _client=client??http.Client(),_storage=secureStorage??const FlutterSecureStorage();
  final http.Client _client; final FlutterSecureStorage _storage;
  static const _accessKey='denupe_access_token',_refreshKey='denupe_refresh_token';
  static const signedUrlTtl=Duration(minutes:4),_pageSize=50,_maxPages=100;
  static final _codePattern=RegExp(r'^[a-z0-9_]+$');
  String? _access,_refresh; DenupeUser? _user;
  bool _sessionValidated=false;
  bool _persistSession=true;
  Future<bool>? _refreshFuture;
  final Map<String,_SignedUrl> _signedUrls={};
  final ValueNotifier<int> authStateTick=ValueNotifier<int>(0);
  String get _base=>Config.apiBaseUrl.replaceFirst(RegExp(r'/+$'),'');
  DenupeUser? get currentUser=>_user;
  bool get isAuthenticated=>_access!=null&&_sessionValidated&&_user!=null;

  Future<void> initialize() async {
    _sessionValidated=false;
    _access=await _storage.read(key:_accessKey);
    _refresh=await _storage.read(key:_refreshKey);
    if(_access==null&&_refresh!=null) await _refreshSession();
    if(_access==null) return;
    try {
      _setUser(await _request('GET','/auth/me'));
      _sessionValidated=_user!=null;
    } on DenupeApiException catch(e) {
      // Una sesión no validada nunca debe abrir el área privada.
      // Si no existe refresh token, el JWT rechazado ya no es recuperable.
      if(e.statusCode==401&&_refresh==null) await _clear();
    } catch (_) {
      // Un fallo transitorio de red no convierte el token en una sesión válida.
      _sessionValidated=false;
    }
  }
  void _setUser(Map<String,dynamic> d){
    final u=d['user']??d;
    if(u is Map&&u['id']!=null){
      final id=u['id'].toString(),email=u['email']?.toString().trim();
      final previous=_user;
      _user=DenupeUser(id:id,email:(email==null||email.isEmpty)?(previous?.id==id?previous?.email:null):email);
    }
  }
  Future<void> _save(Map<String,dynamic>d,{bool? persist})async{
    final a=d['access_token']?.toString(),r=d['refresh_token']?.toString();
    if(a==null||a.isEmpty)throw DenupeApiException('El servidor no devolvió un token.');
    _access=a;if(r!=null&&r.isNotEmpty)_refresh=r;_persistSession=persist??_persistSession;
    if(_persistSession){await _storage.write(key:_accessKey,value:a);if(_refresh!=null)await _storage.write(key:_refreshKey,value:_refresh!);}
    else{await _storage.delete(key:_accessKey);await _storage.delete(key:_refreshKey);}
    _signedUrls.clear();_setUser(d);_sessionValidated=_user!=null;authStateTick.value++;
  }
  Future<void> _clear()async{_access=null;_refresh=null;_user=null;_sessionValidated=false;_persistSession=true;_signedUrls.clear();await _storage.delete(key:_accessKey);await _storage.delete(key:_refreshKey);authStateTick.value++;}
  Map<String,String> _headers(bool auth){final h={'Accept':'application/json'};if(auth&&_access!=null)h['Authorization']='Bearer $_access';return h;}
  Future<http.Response> _send(String method,String path,{Map<String,dynamic>? body,Map<String,String>? query,bool auth=true}) {
    final uri=Uri.parse('$_base/api/v1$path').replace(queryParameters:query==null||query.isEmpty?null:query);
    final h=_headers(auth);if(body!=null)h['Content-Type']='application/json';final b=body==null?null:jsonEncode(body);
    switch(method){case 'GET':return _client.get(uri,headers:h);case 'POST':return _client.post(uri,headers:h,body:b);case 'PATCH':return _client.patch(uri,headers:h,body:b);case 'DELETE':return _client.delete(uri,headers:h);default:throw ArgumentError(method);}
  }
  Future<Map<String,dynamic>> _request(String method,String path,{Map<String,dynamic>? body,Map<String,String>? query,bool auth=true,bool retry=true})async{
    final sentAccess=_access;
    var r=await _send(method,path,body:body,query:query,auth:auth).timeout(const Duration(seconds:30));
    if(r.statusCode==401&&auth&&retry&&_refresh!=null&&path!='/auth/refresh'){
      final rotated=_access!=null&&_access!=sentAccess;
      if(rotated||await _refreshSession())r=await _send(method,path,body:body,query:query,auth:auth).timeout(const Duration(seconds:30));
    }
    if(r.statusCode<200||r.statusCode>=300)throw _exception(r);
    if(r.bodyBytes.isEmpty)return {};
    try{final v=jsonDecode(utf8.decode(r.bodyBytes));return v is Map?Map<String,dynamic>.from(v):{'data':v};}catch(_){throw DenupeApiException('No se pudo interpretar la respuesta del servidor.',statusCode:r.statusCode);}
  }
  String _safeCode(String raw){final v=raw.trim();return v.length<=64&&_codePattern.hasMatch(v)?v:'http_error';}
  String _statusMessage(int s){if(s>=500)return 'El servidor no pudo completar la solicitud.';switch(s){case 400:case 422:return 'Revisa los datos e inténtalo de nuevo.';case 401:case 403:return 'Tu sesión no es válida.';case 404:return 'No se encontró la información solicitada.';case 409:return 'El registro ya existe.';case 429:return 'Demasiadas solicitudes. Inténtalo más tarde.';default:return 'No se pudo completar la solicitud.';}}
  DenupeApiException _exception(http.Response r){
    var code='http_${r.statusCode}',msg=_statusMessage(r.statusCode);
    try{
      final v=jsonDecode(utf8.decode(r.bodyBytes));final d=v is Map?v['detail']:null;
      if(d is String&&d.isNotEmpty){code=_safeCode(d);msg=_messages[code]??msg;}
      else if(d is Map){final raw=d['code']??d['error']??d['type'];if(raw is String&&raw.isNotEmpty){code=_safeCode(raw);msg=_messages[code]??msg;}}
    }catch(_){}
    return DenupeApiException(msg,statusCode:r.statusCode,code:code);
  }
  static const _messages={
    'invalid_credentials':'Correo o contraseña incorrectos.','email_not_verified':'Primero verifica tu correo.',
    'email_or_dni_already_registered':'El correo o DNI ya está registrado.','dni_already_registered':'El DNI ya está registrado.',
    'invalid_or_expired_code':'El código es incorrecto o venció.','invalid_or_expired_reset_token':'El código de recuperación venció.',
    'code_resend_too_soon':'Espera antes de solicitar otro código.','not_authenticated':'Tu sesión venció.',
    'email_delivery_not_configured':'Falta configurar el envío de correo.','verification_email_delivery_failed':'No se pudo enviar el código.',
    'password_reset_email_delivery_failed':'No se pudo enviar el código de recuperación.',
    'perfil_incompleto':'Completa tu perfil para continuar.',
    'estado_no_permitido':'No se permite cambiar a ese estado.',
    'dni_invalido':'Revisa el DNI ingresado.',
    'telefono_invalido':'Revisa el teléfono ingresado.',
    'ruta_territorial_invalida':'La ruta territorial no es válida.',
  };
  Future<bool> _refreshSession() async {
    final pending=_refreshFuture;if(pending!=null)return pending;
    final future=_performRefresh();_refreshFuture=future;
    try{return await future;}finally{if(identical(_refreshFuture,future))_refreshFuture=null;}
  }
  Future<bool> _performRefresh() async {
    final t=_refresh;if(t==null)return false;
    try{
      final d=await _request('POST','/auth/refresh',auth:false,retry:false,body:{'refresh_token':t});
      final r=d['refresh_token'];if(r is! String||r.isEmpty)d['refresh_token']=t;
      await _save(d,persist:_persistSession);return true;
    }on DenupeApiException catch(e){
      final c=(e.code??'').toLowerCase();
      if((e.statusCode==401||e.statusCode==400)&&(c.contains('invalid')||c.contains('expired')||c.contains('revoked')||c.contains('unauthorized')||c=='not_authenticated'))await _clear();
      return false;
    }catch(_){return false;}
  }

  Future<SignUpResult> signUp({required String email,required String password,String? name})async{
    final d=await _request('POST','/auth/register',auth:false,body:{'email':email.trim(),'password':password,'full_name':name});
    final a=d['access_token'];
    if(a is String&&a.isNotEmpty){await _save(d);return const SignUpResult(requireEmailVerification:false);}
    return const SignUpResult(requireEmailVerification:true);
  }
  Future<void> sendVerificationEmail(String email) async { await _request('POST','/auth/email/resend',auth:false,body:{'email':email.trim()}); }
  Future<void> verifyEmail({String? email,required String otp})async{await _save(await _request('POST','/auth/email/verify',auth:false,body:{'email':email?.trim(),'code':otp.trim()}));}
  Future<void> signIn({required String email,required String password,bool rememberMe=true})async{await _save(await _request('POST','/auth/login',auth:false,body:{'email':email.trim(),'password':password}),persist:rememberMe);}
  Future<void> requestPasswordReset({required String email}) async { await _request('POST','/auth/password-reset/request',auth:false,body:{'email':email.trim()}); }
  Future<void> resendPasswordResetCode({required String email}) async { await _request('POST','/auth/password-reset/resend',auth:false,body:{'email':email.trim()}); }
  Future<String> exchangePasswordResetCode({required String email,required String code})async{
    final d=await _request('POST','/auth/password-reset/exchange',auth:false,body:{'email':email.trim(),'code':code.trim()});
    final t=d['token'];if(t is! String||t.trim().isEmpty)throw DenupeApiException('No se pudo validar el código. Inténtalo de nuevo.');
    return t.trim();
  }
  Future<void> resetPassword({required String token,required String newPassword}) async { await _request('POST','/auth/password-reset/confirm',auth:false,body:{'token':token,'new_password':newPassword}); }
  Future<void> signOut()async{try{if(_access!=null)await _request('POST','/auth/logout');}finally{await _clear();}}

  Future<Profile> myProfile()async{final d=await _request('GET','/auth/me');_setUser(d);final p=Map<String,dynamic>.from(d['profile'] as Map? ?? {});p['id']=d['id'];p['created_at']=d['created_at'];return Profile.fromJson(p);}
  Future<void> updateProfile({required String fullName,String? dni,String? phone,String? district})async{await _request('PATCH','/auth/me',body:{'full_name':fullName,'dni':(dni==null||dni.trim().isEmpty)?null:dni.trim(),'phone':phone,'district':district});}
  Future<List<Category>> categories()async{final d=await _request('GET','/catalogos/categorias');return (d['data'] as List? ?? []).map((x)=>Category.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<List<Authority>> authorities()async{final d=await _request('GET','/catalogos/autoridades');return (d['data'] as List? ?? []).map((x)=>Authority.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<List<Map<String,dynamic>>> districts({String? search,int limit=50})async{final d=await _request('GET','/catalogos/distritos',query:{'limit':'$limit',if(search!=null&&search.isNotEmpty)'search':search});return List<Map<String,dynamic>>.from(d['data'] as List? ?? []);}
  Future<List<Map<String,dynamic>>> entities()async{final d=await _request('GET','/catalogos/entidades');return List<Map<String,dynamic>>.from(d['data'] as List? ?? []);}

  Future<List<Map<String,dynamic>>> _allRows(String path,{int limit=_pageSize,int offset=0})async{
    final size=limit<1?_pageSize:limit;var current=offset<0?0:offset;
    final seen=<String>{},out=<Map<String,dynamic>>[];
    for(var page=0;page<_maxPages;page++){
      final d=await _request('GET',path,query:{'limit':'$size','offset':'$current'});
      final rows=List<Map<String,dynamic>>.from(d['data'] as List? ?? []);
      if(rows.isEmpty)break;
      final fresh=rows.where((row){final id=row['id']?.toString();return id==null||seen.add(id);}).toList();
      if(fresh.isEmpty)break;
      out.addAll(fresh);current+=fresh.length;
      final total=d['total']??d['count'];
      if(rows.length<size||(total is num&&current>=total))break;
    }
    return out;
  }
  Future<List<Complaint>> myComplaints({int limit=_pageSize,int offset=0})async=>(await _allRows('/denuncias',limit:limit,offset:offset)).map((x)=>Complaint.fromJson(x)).toList();
  Future<List<Complaint>> panelComplaints({int limit=_pageSize,int offset=0})=>myComplaints(limit:limit,offset:offset);
  Future<List<Complaint>> authorityComplaints({int limit=_pageSize,int offset=0})=>myComplaints(limit:limit,offset:offset);
  Future<Complaint> createComplaint({required String categoryId,required String title,required String description,String? address,double? latitude,double? longitude,String? autoridadId,String? entidadPublicaId,String? entidadPublicaNombre,String? rutaTerritorialCode,String? districtUbigeo,String? denuncianteNombre,String? denuncianteDni,String? denuncianteEmail,String? denuncianteTelefono})async{
    final d=await _request('POST','/denuncias',body:{'category_id':categoryId,'title':title,'description':description,'address':address,'latitude':latitude,'longitude':longitude,'autoridad_id':autoridadId,'entidad_publica_id':entidadPublicaId,'entidad_publica_nombre':entidadPublicaNombre,'ruta_territorial_code':rutaTerritorialCode,'district_ubigeo':districtUbigeo,'denunciante_nombre':denuncianteNombre,'denunciante_dni':denuncianteDni,'denunciante_email':denuncianteEmail,'denunciante_telefono':denuncianteTelefono});return Complaint.fromJson(d);
  }
  Future<Complaint?> complaintById(String id)async{try{return Complaint.fromJson(await _request('GET','/denuncias/$id'));}on DenupeApiException catch(e){if(e.statusCode==404)return null;rethrow;}}
  Future<void> updateComplaintStatus({required String complaintId,required String newStatus,String? note}) async { await _request('PATCH','/denuncias/$complaintId/estado',body:{'status':newStatus,'note':note}); }
  Future<List<StatusHistory>> complaintHistory(String id)async{final d=await _request('GET','/denuncias/$id/historial');return (d['data'] as List? ?? []).map((x)=>StatusHistory.fromJson(Map<String,dynamic>.from(x))).toList();}

  Future<ComplaintMedia> uploadComplaintMedia({required String complaintId,required Uint8List bytes,required String filename,required String contentType,required String mediaType})async{
    final up=await _request('POST','/denuncias/$complaintId/adjuntos/upload-url',body:{'filename':filename,'mime_type':contentType,'size_bytes':bytes.length});
    final rawUrl=up['upload_url'];if(rawUrl is! String||!_isSafeSignedUrl(rawUrl))throw DenupeApiException('No se pudo preparar la subida de la evidencia.');
    final uri=Uri.parse(rawUrl.trim());
    final rawHeaders=up['headers'];if(rawHeaders is! Map)throw DenupeApiException('No se pudo preparar la subida de la evidencia.');
    final headers=<String,String>{};rawHeaders.forEach((k,v){if(v!=null)headers[k.toString()]=v.toString();});
    final key=up['storage_key'];if(key is! String||key.trim().isEmpty)throw DenupeApiException('No se pudo preparar la subida de la evidencia.');
    final put=await _client.put(uri,headers:headers,body:bytes).timeout(const Duration(seconds:60));
    if(put.statusCode<200||put.statusCode>=300)throw DenupeApiException('No se pudo subir la evidencia a R2.',statusCode:put.statusCode);
    final d=await _request('POST','/denuncias/$complaintId/adjuntos/confirm',body:{'storage_key':key});
    d['complaint_id']=complaintId;d['user_id']=_user?.id??'';d['url']='';return ComplaintMedia.fromJson(d);
  }
  Future<_SignedUrl> _signedUrlForAttachment(String complaintId,Object? attachmentId)async{
    final d=await _request('GET','/denuncias/$complaintId/adjuntos/$attachmentId/download-url');
    final u=d['download_url'];
    if(u is! String||!_isSafeSignedUrl(u))throw DenupeApiException('No se pudo preparar la descarga de la evidencia.');
    return _SignedUrl(u.trim(),_signedUrlExpiry(d));
  }
  Future<List<ComplaintMedia>> complaintMedia(String id)async{
    final d=await _request('GET','/denuncias/$id/adjuntos');final rows=List<Map<String,dynamic>>.from(d['data'] as List? ?? []);final out=<ComplaintMedia>[];
    for(final row in rows){
      try{
        final signed=await _signedUrlForAttachment(id,row['id']);
        row['url']=signed.url;
        final key=row['storage_key']?.toString();
        if(key!=null&&key.isNotEmpty)_signedUrls[key]=signed;
      }catch(_){row['url']='';}
      out.add(ComplaintMedia.fromJson(row));
    }
    return out;
  }
  Future<_SignedUrl> _downloadUrlFor(String complaintId,String storageKey)async{
    final d=await _request('GET','/denuncias/$complaintId/adjuntos');
    for(final row in List<Map<String,dynamic>>.from(d['data'] as List? ?? [])){
      if(row['storage_key']?.toString()!=storageKey)continue;
      return _signedUrlForAttachment(complaintId,row['id']);
    }
    throw DenupeApiException('No se encontró la evidencia.');
  }
  Future<_SignedUrl> _findSignedUrl(String storageKey)async{
    for(final c in await myComplaints()){
      final d=await _request('GET','/denuncias/${c.id}/adjuntos');
      final match=List<Map<String,dynamic>>.from(d['data'] as List? ?? []).where((row)=>row['storage_key']?.toString()==storageKey).cast<Map<String,dynamic>>().toList();
      if(match.isEmpty)continue;
      return _signedUrlForAttachment(c.id,match.first['id']);
    }
    throw DenupeApiException('No se encontró la evidencia.');
  }
  Future<String> complaintMediaSignedUrl(String storageKey,{String? complaintId,bool forceRefresh=false,bool refresh=false})async{
    final key=storageKey.trim();if(key.isEmpty)throw DenupeApiException('No se encontró la evidencia.');
    final cached=_signedUrls[key];
    if(!forceRefresh&&!refresh&&cached!=null&&DateTime.now().isBefore(cached.expiresAt))return cached.url;
    _signedUrls.remove(key);
    final signed=complaintId!=null?await _downloadUrlFor(complaintId,key):await _findSignedUrl(key);
    _signedUrls[key]=signed;return signed.url;
  }
  Future<void> deleteComplaintMedia(ComplaintMedia media)async{await _request('DELETE','/denuncias/${media.complaintId}/adjuntos/${media.id}');}
  Future<Map<String,dynamic>> aiSuggestCategory({required String title,required String description}) async =>
      _request('POST','/ia/sugerir-categoria',body:{'titulo':title.trim(),'descripcion':description.trim()});
  Future<Map<String,dynamic>> aiAvailableEntities({required String category,required double latitude,required double longitude}) async =>
      _request('GET','/ia/entidades/disponibles',query:{'categoria':category,'latitud':'$latitude','longitud':'$longitude'});
  Future<Map<String,dynamic>> aiTerritorialCatalog({required double latitude,required double longitude}) async =>
      _request('GET','/ia/territorio/catalogo-distrital',query:{'latitud':'$latitude','longitud':'$longitude'});
  Future<Map<String,dynamic>> aiSuggestEntity(Map<String,dynamic> payload) async =>
      _request('POST','/ia/sugerir-entidad',body:payload);

  Future<List<AppNotification>> notifications({int limit=_pageSize,int offset=0})async=>(await _allRows('/notificaciones',limit:limit,offset:offset)).map((x)=>AppNotification.fromJson(x)).toList();
  Future<void> markNotificationRead(String id) async { await _request('PATCH','/notificaciones/$id/leida'); }
  Future<List<String>> markAllNotificationsRead()async{
    final failed=<String>[];
    for(final n in (await notifications()).where((x)=>!x.isRead)){
      try{await markNotificationRead(n.id);}catch(_){failed.add(n.id);}
    }
    return failed;
  }
  Future<int> unreadNotificationsCount()async=>(await notifications()).where((x)=>!x.isRead).length;
  void dispose()=>_client.close();
}
