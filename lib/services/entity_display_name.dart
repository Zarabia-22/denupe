String entityDisplayName({
  String? reference,
  String? type,
  String? district,
}) {
  final label = reference?.trim() ?? '';
  final normalized = _normalize(label);
  final kind = _normalize(type);
  final place = district?.trim() ?? '';
  final suffix = place.isEmpty ? '' : ' de $place';

  const genericQualifiers = <String>[
    'competente',
    'correspondiente',
    'responsable',
    'por identificar',
    'no disponible',
    'por determinar',
    'a determinar',
    'sin nombre',
    'ubigeo',
    'competencia',
  ];
  final isGeneric = normalized.isEmpty ||
      genericQualifiers.any(normalized.contains) ||
      (normalized.contains('provincial o distrital'));

  if (!isGeneric) return label;

  if (kind.contains('municipalidad')) return 'Municipalidad$suffix';
  if (kind.contains('comisaria') || kind.contains('pnp')) {
    return 'Comisaría PNP$suffix';
  }
  if (kind.contains('serenazgo')) return 'Serenazgo$suffix';
  if (kind.contains('electrica') || kind.contains('concesionaria')) {
    return 'Empresa eléctrica$suffix';
  }
  if (kind.contains('saneamiento') || kind.contains('operador')) {
    return 'Operador de saneamiento$suffix';
  }
  if (kind.contains('transporte')) return 'Autoridad de transporte$suffix';
  if (kind.contains('vial')) return 'Titular vial$suffix';
  if (kind.contains('revision')) return 'Atención territorial$suffix';
  return place.isEmpty ? 'Atención territorial' : 'Atención en $place';
}

String _normalize(String? value) => (value ?? '')
    .toLowerCase()
    .replaceAll(RegExp(r'[áàäâ]'), 'a')
    .replaceAll(RegExp(r'[éèëê]'), 'e')
    .replaceAll(RegExp(r'[íìïî]'), 'i')
    .replaceAll(RegExp(r'[óòöô]'), 'o')
    .replaceAll(RegExp(r'[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
