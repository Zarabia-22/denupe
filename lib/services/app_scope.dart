import 'package:flutter/foundation.dart' show ValueNotifier;

import '../models.dart';
import 'complaint_realtime.dart';
import 'denupe_api.dart';

/// Acceso global a los servicios de la app.
final DenupeApi api = DenupeApi();
final ComplaintRealtime realtime = ComplaintRealtime(api);

const _catalogTtl = Duration(minutes: 5);
List<Category>? _categoriesCache;
List<Authority>? _authoritiesCache;
DateTime? _categoriesAt, _authoritiesAt;
String? _categoriesUser, _authoritiesUser;
bool _catalogListenerAdded = false;

void _invalidateCatalogCaches() {
  _categoriesCache = null;
  _authoritiesCache = null;
  _categoriesAt = null;
  _authoritiesAt = null;
  _categoriesUser = null;
  _authoritiesUser = null;
}

void _ensureCatalogListener() {
  if (_catalogListenerAdded) return;
  _catalogListenerAdded = true;
  api.authStateTick.addListener(_invalidateCatalogCaches);
}

Future<List<Category>> categories() async {
  _ensureCatalogListener();
  final user = api.currentUser?.id;
  final cached = _categoriesCache;
  final at = _categoriesAt;
  if (cached != null &&
      at != null &&
      _categoriesUser == user &&
      DateTime.now().difference(at).compareTo(_catalogTtl) < 0) {
    return cached;
  }
  final value = await api.categories();
  _categoriesCache = value;
  _categoriesAt = DateTime.now();
  _categoriesUser = user;
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

Future<List<Authority>> authorities() async {
  _ensureCatalogListener();
  final user = api.currentUser?.id;
  final cached = _authoritiesCache;
  final at = _authoritiesAt;
  if (cached != null &&
      at != null &&
      _authoritiesUser == user &&
      DateTime.now().difference(at).compareTo(_catalogTtl) < 0) {
    return cached;
  }
  final value = await api.authorities();
  _authoritiesCache = value;
  _authoritiesAt = DateTime.now();
  _authoritiesUser = user;
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
/// (cambios de estado detectados por sondeo, lectura, etc.) para refrescar la pantalla.
final ValueNotifier<int> notificationsTick = ValueNotifier<int>(0);

void bumpNotificationsTick() {
  notificationsTick.value++;
}
