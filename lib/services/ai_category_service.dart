import '../services/app_scope.dart';
import '../services/denupe_api.dart';

class AiCategorySuggestion {
  const AiCategorySuggestion({required this.sugerida,this.categoria,this.motivo});
  final bool sugerida;
  final String? categoria;
  final String? motivo;
  factory AiCategorySuggestion.fromJson(Map<String,dynamic> json)=>AiCategorySuggestion(
    sugerida:json['sugerida']==true,
    categoria:json['categoria'] as String?,
    motivo:json['motivo'] as String?,
  );
}

/// Usa el proxy autenticado del backend principal; Flutter no llama directamente
/// al microservicio IA ni necesita exponer su URL en el dispositivo.
class AiCategoryService {
  Future<AiCategorySuggestion> sugerirCategoria({required String titulo,required String descripcion}) async {
    try {
      final data=await api.aiSuggestCategory(title:titulo,description:descripcion);
      return AiCategorySuggestion.fromJson(data);
    } on DenupeApiException catch(e) {
      throw AiCategoryException('${e.message}. Puedes elegir una categoría manualmente.');
    } catch (_) {
      throw const AiCategoryException('No se pudo obtener la sugerencia. Puedes elegir una categoría manualmente.');
    }
  }
}
class AiCategoryException implements Exception {
  const AiCategoryException(this.message);
  final String message;
  @override String toString()=>message;
}
