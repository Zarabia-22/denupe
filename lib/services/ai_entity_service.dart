import 'package:http/http.dart' as http;
import '../services/app_scope.dart';
import '../services/denupe_api.dart';

class AiPublicEntity {
  const AiPublicEntity({required this.id,required this.nombre,required this.tipo,required this.ambito,this.direccion,this.telefono,this.sitioWeb,this.entidadReferencia,this.metodoResolucion,this.categoriaCode});
  final String id,nombre,tipo;
  final String? direccion,telefono,sitioWeb;
  final Map<String,String> ambito;
  final String? entidadReferencia,metodoResolucion,categoriaCode;
  factory AiPublicEntity.fromJson(Map<String,dynamic> json){
    final raw=json['ambito'];final area=<String,String>{};
    if(raw is Map){raw.forEach((k,v){if(v!=null)area[k.toString()]=v.toString();});}
    return AiPublicEntity(
      id:json['id']?.toString()??'',nombre:json['nombre']?.toString()??'',
      tipo:json['tipo']?.toString()??'',direccion:json['direccion'] as String?,
      telefono:json['telefono'] as String?,sitioWeb:json['sitio_web'] as String?,
      ambito:area,entidadReferencia:json['entidad_referencia']?.toString(),
      metodoResolucion:json['metodo_resolucion']?.toString(),categoriaCode:json['categoria_code']?.toString(),
    );
  }
}
class AiEntitySuggestion {
  const AiEntitySuggestion({required this.sugerida,required this.motivo,this.entidad});
  final bool sugerida;final String motivo;final AiPublicEntity? entidad;
  factory AiEntitySuggestion.fromJson(Map<String,dynamic> json){
    final raw=json['entidad'];
    return AiEntitySuggestion(
      sugerida:json['sugerida']==true,
      motivo:json['motivo']?.toString()??'No se encontró una entidad verificable.',
      entidad:raw is Map?AiPublicEntity.fromJson(Map<String,dynamic>.from(raw)):null,
    );
  }
}

/// Proxy de IA del backend principal. El cliente móvil no consume directamente
/// la URL del microservicio ni depende de credenciales/URLs InsForge.
class AiEntityService {
  AiEntityService({http.Client? client,DenupeApi? apiClient})
      : _api=apiClient??(client==null?api:DenupeApi(client:client));
  final DenupeApi _api;
  Future<List<AiPublicEntity>> listarEntidadesDisponibles({required String categoria,required double latitud,required double longitud}) async {
    try {
      final data=await _api.aiAvailableEntities(category:categoria,latitude:latitud,longitude:longitud);
      final rows=data['entidades'];
      if(rows is! List)throw const FormatException('Respuesta inválida del catálogo');
      return rows.whereType<Map>().map((x)=>AiPublicEntity.fromJson(Map<String,dynamic>.from(x))).toList();
    } on DenupeApiException catch(e){throw AiEntityException(e.message);}
    catch(_){throw const AiEntityException('No se pudo cargar el catálogo de instituciones del distrito.');}
  }

  Future<List<AiPublicEntity>> listarCatalogoTerritorial({required double latitud,required double longitud}) async {
    try {
      final data=await _api.aiTerritorialCatalog(latitude:latitud,longitude:longitud);
      final rows=data['categorias'];
      if(rows is! List)throw const FormatException('Respuesta inválida del catálogo territorial');
      final area=<String,String>{
        'departamento':data['departamento']?.toString()??'',
        'provincia':data['provincia']?.toString()??'',
        'distrito':data['distrito']?.toString()??'',
      };
      const names={
        'alumbrado':'Alumbrado público','seguridad':'Seguridad ciudadana',
        'limpieza':'Limpieza y residuos','agua':'Agua y saneamiento',
        'transito':'Tránsito y transporte','areas_verdes':'Parques y áreas verdes',
        'infraestructura':'Vialidad e infraestructura','otros':'Otros',
      };
      return rows.whereType<Map>().map((raw){
        final item=Map<String,dynamic>.from(raw);
        final code=item['categoria_code']?.toString()??'';
        return AiPublicEntity(
          id:code,nombre:names[code]??(code.isEmpty?'Categoría':code),
          tipo:item['entidad_tipo']?.toString()??'',ambito:area,
          entidadReferencia:item['entidad_nombre']?.toString(),
          metodoResolucion:item['metodo_resolucion']?.toString(),categoriaCode:code,
        );
      }).where((x)=>x.id.isNotEmpty).toList();
    } on DenupeApiException catch(e){throw AiEntityException(e.message);}
    catch(_){throw const AiEntityException('No se pudo cargar el catálogo territorial.');}
  }

  Future<AiEntitySuggestion> sugerirEntidad({
    required String categoria,required String departamento,required String provincia,
    required String distrito,required String titulo,required String descripcion,
    double? latitud,double? longitud,
  }) async {
    try {
      final data=await _api.aiSuggestEntity({
        'categoria':categoria,'departamento':departamento,'provincia':provincia,
        'distrito':distrito,'titulo':titulo.trim(),'descripcion':descripcion.trim(),
        if(latitud!=null&&longitud!=null)'latitud':latitud,
        if(latitud!=null&&longitud!=null)'longitud':longitud,
      });
      return AiEntitySuggestion.fromJson(data);
    } on DenupeApiException catch(e){throw AiEntityException(e.message);}
    catch(_){throw const AiEntityException('No se pudo conectar con el servicio de recomendación. Puedes continuar manualmente.');}
  }
}
class AiEntityException implements Exception {
  const AiEntityException(this.message);
  final String message;
  @override String toString()=>message;
}
