import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:insforge_flutter/insforge_flutter.dart';

import '../config.dart';
import '../models.dart';
import 'complaint_realtime.dart';
import 'denupe_api.dart';

/// Acceso global a los servicios de la app.
final DenupeApi api = DenupeApi(Insforge.instance);
final ComplaintRealtime realtime = ComplaintRealtime(Config.baseUrl);

List<Category>? _categoriesCache;

/// Categorías, cacheadas la primera vez (se cargan en el backend).
Future<List<Category>> categories() async {
  final cached = _categoriesCache;
  if (cached != null) return cached;
  final value = await api.categories();
  _categoriesCache = value;
  return value;
}

String categoryNameOf(List<Category> list, String? id) {
  if (id == null) return 'General';
  for (final c in list) {
    if (c.id == id) return c.name;
  }
  return 'General';
}

/// Nombre de categoría desde el caché global (si ya se cargó).
String categoryNameFromCache(String? id) {
  final list = _categoriesCache;
  if (list == null || id == null) return 'General';
  return categoryNameOf(list, id);
}

List<Authority>? _authoritiesCache;

/// Entidades receptoras, cacheadas la primera vez (se cargan en el backend).
Future<List<Authority>> authorities() async {
  final cached = _authoritiesCache;
  if (cached != null) return cached;
  final value = await api.authorities();
  _authoritiesCache = value;
  return value;
}

String authorityNameOf(List<Authority> list, String? id) {
  if (id == null) return 'Por asignar';
  for (final a in list) {
    if (a.id == id) return a.nombre;
  }
  return 'Por asignar';
}

/// Nombre de la entidad desde el caché global (si ya se cargó).
String authorityNameFromCache(String? id) {
  final list = _authoritiesCache;
  if (list == null || id == null) return 'Por asignar';
  return authorityNameOf(list, id);
}

/// Contador que se incrementa cada vez que cambian las notificaciones
/// (evento realtime, lectura, etc.) para que la pantalla se refresque.
final ValueNotifier<int> notificationsTick = ValueNotifier<int>(0);

void bumpNotificationsTick() {
  notificationsTick.value++;
}

/// Token de acceso de la sesión activa (para realtime y llamadas autenticadas).
String? currentAccessToken() =>
    Insforge.instance.auth.currentSession?.accessToken;