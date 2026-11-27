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
class DenupeUser { const DenupeUser({required this.id,required this.email}); final String id,email; }
class SignUpResult { const SignUpResult({required this.requireEmailVerification}); final bool requireEmailVerification; }

class DenupeApi {
  DenupeApi({http.Client? client,FlutterSecureStorage? secureStorage})
    : _client=client??http.Client(),_storage=secureStorage??const FlutterSecureStorage();
  final http.Client _client; final FlutterSecureStorage _storage;
  static const _accessKey='denupe_access_token',_refreshKey='denupe_refresh_token';
  String? _access,_refresh; DenupeUser? _user;
  bool _persistSession=true;
  final ValueNotifier<int> authStateTick=ValueNotifier<int>(0);
  String get _base=>Config.apiBaseUrl.replaceFirst(RegExp(r'/+$'),'');
  DenupeUser? get currentUser=>_user; String? get accessToken=>_access;
  bool get isAuthenticated=>_access!=null;

  Future<void> initialize() async {
    _access=await _storage.read(key:_accessKey); _refresh=await _storage.read(key:_refreshKey);
    if(_access==null)return;
    try{_setUser(await _request('GET','/auth/me'));}on DenupeApiException catch(e){if(e.statusCode==401)await _clear();}catch(_){}
  }
  void _setUser(Map<String,dynamic> d){final u=d['user']??d;if(u is Map&&u['id']!=null&&u['email']!=null)_user=DenupeUser(id:u['id'].toString(),email:u['email'].toString());}
  Future<void> _save(Map<String,dynamic>d,{bool? persist})async{
    final a=d['access_token']?.toString(),r=d['refresh_token']?.toString();
    if(a==null||a.isEmpty)throw DenupeApiException('El servidor no devolvió un token.');
    _access=a;_refresh=r;_persistSession=persist??_persistSession;
    if(_persistSession){await _storage.write(key:_accessKey,value:a);if(r!=null)await _storage.write(key:_refreshKey,value:r);}
    else{await _storage.delete(key:_accessKey);await _storage.delete(key:_refreshKey);}
    _setUser(d);authStateTick.value++;
  }
  Future<void> _clear()async{_access=null;_refresh=null;_user=null;_persistSession=true;await _storage.delete(key:_accessKey);await _storage.delete(key:_refreshKey);authStateTick.value++;}
  Map<String,String> _headers(bool auth){final h={'Accept':'application/json'};if(auth&&_access!=null)h['Authorization']='Bearer $_access';return h;}
  Future<http.Response> _send(String method,String path,{Map<String,dynamic>? body,Map<String,String>? query,bool auth=true}) {
    final uri=Uri.parse('$_base/api/v1$path').replace(queryParameters:query==null||query.isEmpty?null:query);
    final h=_headers(auth);if(body!=null)h['Content-Type']='application/json';final b=body==null?null:jsonEncode(body);
    switch(method){case 'GET':return _client.get(uri,headers:h);case 'POST':return _client.post(uri,headers:h,body:b);case 'PATCH':return _client.patch(uri,headers:h,body:b);case 'DELETE':return _client.delete(uri,headers:h);default:throw ArgumentError(method);}
  }
  Future<Map<String,dynamic>> _request(String method,String path,{Map<String,dynamic>? body,Map<String,String>? query,bool auth=true,bool retry=true})async{
    var r=await _send(method,path,body:body,query:query,auth:auth);
    if(r.statusCode==401&&auth&&retry&&_refresh!=null&&path!='/auth/refresh'){if(await _refreshSession())r=await _send(method,path,body:body,query:query);}
    if(r.statusCode<200||r.statusCode>=300)throw _exception(r);
    if(r.bodyBytes.isEmpty)return {};
    final v=jsonDecode(utf8.decode(r.bodyBytes));return v is Map?Map<String,dynamic>.from(v):{'data':v};
  }
  DenupeApiException _exception(http.Response r){var code='http_error',msg='No se pudo completar la solicitud.';try{final v=jsonDecode(utf8.decode(r.bodyBytes));final d=v is Map?v['detail']:null;if(d is String){code=d;msg=_messages[d]??d.replaceAll('_',' ');}else if(d!=null)msg=d.toString();}catch(_){}return DenupeApiException(msg,statusCode:r.statusCode,code:code);}
  static const _messages={
    'invalid_credentials':'Correo o contraseña incorrectos.','email_not_verified':'Primero verifica tu correo.',
    'email_or_dni_already_registered':'El correo o DNI ya está registrado.','dni_already_registered':'El DNI ya está registrado.',
    'invalid_or_expired_code':'El código es incorrecto o venció.','invalid_or_expired_reset_token':'El código de recuperación venció.',
    'code_resend_too_soon':'Espera antes de solicitar otro código.','not_authenticated':'Tu sesión venció.',
    'email_delivery_not_configured':'Falta configurar el envío de correo.','verification_email_delivery_failed':'No se pudo enviar el código.',
    'password_reset_email_delivery_failed':'No se pudo enviar el código de recuperación.',
  };
  Future<bool> _refreshSession()async{final t=_refresh;if(t==null)return false;try{final d=await _request('POST','/auth/refresh',auth:false,retry:false,body:{'refresh_token':t});await _save(d,persist:_persistSession);return true;}catch(_){await _clear();return false;}}

  Future<SignUpResult> signUp({required String email,required String password,String? name})async{await _request('POST','/auth/register',auth:false,body:{'email':email.trim(),'password':password,'full_name':name});return const SignUpResult(requireEmailVerification:true);}
  Future<void> sendVerificationEmail(String email) async { await _request('POST','/auth/email/resend',auth:false,body:{'email':email.trim()}); }
  Future<void> verifyEmail({String? email,required String otp})async{await _save(await _request('POST','/auth/email/verify',auth:false,body:{'email':email?.trim(),'code':otp.trim()}));}
  Future<void> signIn({required String email,required String password,bool rememberMe=true})async{await _save(await _request('POST','/auth/login',auth:false,body:{'email':email.trim(),'password':password}),persist:rememberMe);}
  Future<void> requestPasswordReset({required String email}) async { await _request('POST','/auth/password-reset/request',auth:false,body:{'email':email.trim()}); }
  Future<void> resendPasswordResetCode({required String email}) async { await _request('POST','/auth/password-reset/resend',auth:false,body:{'email':email.trim()}); }
  Future<String> exchangePasswordResetCode({required String email,required String code})async{final d=await _request('POST','/auth/password-reset/exchange',auth:false,body:{'email':email.trim(),'code':code.trim()});return d['token'].toString();}
  Future<void> resetPassword({required String token,required String newPassword}) async { await _request('POST','/auth/password-reset/confirm',auth:false,body:{'token':token,'new_password':newPassword}); }
  Future<void> signOut()async{try{if(_access!=null)await _request('POST','/auth/logout');}finally{await _clear();}}

  Future<Profile> myProfile()async{final d=await _request('GET','/auth/me');_setUser(d);final p=Map<String,dynamic>.from(d['profile'] as Map? ?? {});p['id']=d['id'];p['created_at']=d['created_at'];return Profile.fromJson(p);}
  Future<void> updateProfile({required String fullName,String? dni,String? phone,String? district})async{await _request('PATCH','/auth/me',body:{'full_name':fullName,'dni':(dni==null||dni.trim().isEmpty)?null:dni.trim(),'phone':phone,'district':district});}
  Future<List<Category>> categories()async{final d=await _request('GET','/catalogos/categorias');return (d['data'] as List? ?? []).map((x)=>Category.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<List<Authority>> authorities()async{final d=await _request('GET','/catalogos/autoridades');return (d['data'] as List? ?? []).map((x)=>Authority.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<List<Map<String,dynamic>>> districts({String? search,int limit=50})async{final d=await _request('GET','/catalogos/distritos',query:{'limit':'$limit',if(search!=null&&search.isNotEmpty)'search':search});return List<Map<String,dynamic>>.from(d['data'] as List? ?? []);}
  Future<List<Map<String,dynamic>>> entities()async{final d=await _request('GET','/catalogos/entidades');return List<Map<String,dynamic>>.from(d['data'] as List? ?? []);}

  Future<List<Complaint>> myComplaints()async{final d=await _request('GET','/denuncias');return (d['data'] as List? ?? []).map((x)=>Complaint.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<List<Complaint>> authorityComplaints()=>myComplaints();
  Future<Complaint> createComplaint({required String categoryId,required String title,required String description,String? address,double? latitude,double? longitude,String? autoridadId,String? entidadPublicaId,String? entidadPublicaNombre,String? rutaTerritorialCode,String? districtUbigeo,String? denuncianteNombre,String? denuncianteDni,String? denuncianteEmail,String? denuncianteTelefono})async{
    final d=await _request('POST','/denuncias',body:{'category_id':categoryId,'title':title,'description':description,'address':address,'latitude':latitude,'longitude':longitude,'autoridad_id':autoridadId,'entidad_publica_id':entidadPublicaId,'entidad_publica_nombre':entidadPublicaNombre,'ruta_territorial_code':rutaTerritorialCode,'district_ubigeo':districtUbigeo,'denunciante_nombre':denuncianteNombre,'denunciante_dni':denuncianteDni,'denunciante_email':denuncianteEmail,'denunciante_telefono':denuncianteTelefono});return Complaint.fromJson(d);
  }
  Future<Complaint?> complaintById(String id)async{try{return Complaint.fromJson(await _request('GET','/denuncias/$id'));}on DenupeApiException catch(e){if(e.statusCode==404)return null;rethrow;}}
  Future<void> updateComplaintStatus({required String complaintId,required String newStatus,String? note}) async { await _request('PATCH','/denuncias/$complaintId/estado',body:{'status':newStatus,'note':note}); }
  Future<List<StatusHistory>> complaintHistory(String id)async{final d=await _request('GET','/denuncias/$id/historial');return (d['data'] as List? ?? []).map((x)=>StatusHistory.fromJson(Map<String,dynamic>.from(x))).toList();}

  Future<ComplaintMedia> uploadComplaintMedia({required String complaintId,required Uint8List bytes,required String filename,required String contentType,required String mediaType})async{
    final up=await _request('POST','/denuncias/$complaintId/adjuntos/upload-url',body:{'filename':filename,'mime_type':contentType,'size_bytes':bytes.length});
    final put=await _client.put(Uri.parse(up['upload_url'].toString()),headers:Map<String,String>.from(up['headers'] as Map),body:bytes);
    if(put.statusCode<200||put.statusCode>=300)throw DenupeApiException('No se pudo subir la evidencia a R2.',statusCode:put.statusCode);
    final d=await _request('POST','/denuncias/$complaintId/adjuntos/confirm',body:{'storage_key':up['storage_key']});
    d['complaint_id']=complaintId;d['user_id']=_user?.id??'';d['url']='';return ComplaintMedia.fromJson(d);
  }
  Future<List<ComplaintMedia>> complaintMedia(String id)async{
    final d=await _request('GET','/denuncias/$id/adjuntos');final rows=List<Map<String,dynamic>>.from(d['data'] as List? ?? []);final out=<ComplaintMedia>[];
    for(final row in rows){try{final signed=await _request('GET','/denuncias/$id/adjuntos/${row['id']}/download-url');row['url']=signed['download_url'];}catch(_){row['url']='';}out.add(ComplaintMedia.fromJson(row));}return out;
  }
  Future<String> complaintMediaSignedUrl(String key)async{
    final complaints=await myComplaints();for(final c in complaints){final d=await _request('GET','/denuncias/${c.id}/adjuntos');for(final row in List<Map<String,dynamic>>.from(d['data'] as List? ?? [])){if(row['storage_key']==key){final u=await _request('GET','/denuncias/${c.id}/adjuntos/${row['id']}/download-url');return u['download_url'].toString();}}}throw DenupeApiException('No se encontró la evidencia.');
  }
  Future<void> deleteComplaintMedia(ComplaintMedia media)async{await _request('DELETE','/denuncias/${media.complaintId}/adjuntos/${media.id}');}
  Future<Map<String,dynamic>> aiSuggestCategory({required String title,required String description}) async =>
      _request('POST','/ia/sugerir-categoria',body:{'titulo':title.trim(),'descripcion':description.trim()});
  Future<Map<String,dynamic>> aiAvailableEntities({required double latitude,required double longitude}) async =>
      _request('GET','/ia/entidades/disponibles',query:{'latitud':'$latitude','longitud':'$longitude'});
  Future<Map<String,dynamic>> aiTerritorialCatalog({required double latitude,required double longitude}) async =>
      _request('GET','/ia/territorio/catalogo-distrital',query:{'latitud':'$latitude','longitud':'$longitude'});
  Future<Map<String,dynamic>> aiSuggestEntity(Map<String,dynamic> payload) async =>
      _request('POST','/ia/sugerir-entidad',body:payload);

  Future<List<AppNotification>> notifications()async{final d=await _request('GET','/notificaciones');return (d['data'] as List? ?? []).map((x)=>AppNotification.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<void> markNotificationRead(String id) async { await _request('PATCH','/notificaciones/$id/leida'); }
  Future<void> markAllNotificationsRead()async{for(final n in (await notifications()).where((x)=>!x.isRead)){await markNotificationRead(n.id);}}
  Future<int> unreadNotificationsCount()async=>(await notifications()).where((x)=>!x.isRead).length;
  void dispose()=>_client.close();
}
