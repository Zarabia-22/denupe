import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import '../widgets/location_preview.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/ai_entity_service.dart';

class ComplaintConfirmationScreen extends StatefulWidget {
  const ComplaintConfirmationScreen({
    super.key,
    required this.categoryId,
    required this.title,
    required this.description,
    this.address,
    this.latitude,
    this.longitude,
    required this.media,
    required this.categories,
    this.district,
  });

  final String categoryId;
  final String title;
  final String description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<ComplaintAttachment> media;
  final List<Category> categories;
  final String? district;

  @override
  State<ComplaintConfirmationScreen> createState() =>
      _ComplaintConfirmationScreenState();
}

class _ComplaintConfirmationScreenState
    extends State<ComplaintConfirmationScreen> {
  List<Authority> _autoridades = [];
  List<AiPublicEntity> _availableEntities = [];
  AiPublicEntity? _selectedPublicEntity;
  String _entitySearchQuery = '';
  bool _loadingEntities = false;
  String? _selectedAuthorityId;
  bool _confirming = false;
  bool _suggestingEntity = false;
  AiEntitySuggestion? _entitySuggestion;

  @override
  void initState() {
    super.initState();
    _loadAutoridades();
    _loadManualEntities();
  }

  Future<void> _loadAutoridades() async {
    // El catálogo local solo se consulta para traducir tipos de entidad
    // compatibles. Un fallo aquí no impide registrar la denuncia: la BD
    // conserva su asignación predeterminada por categoría.
    try {
      final list = await authorities();
      if (!mounted) return;
      setState(() => _autoridades = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _autoridades = []);
    }
  }


  Future<void> _loadManualEntities() async {
    final territory = _territoryForDistrict(widget.district);
    if (territory == null) return;
    if (_autoridades.isEmpty) await _loadAutoridades();
    if (!mounted) return;
    setState(() => _loadingEntities = true);
    try {
      final entities = await AiEntityService().listarEntidadesDisponibles(
        categoria: _categoryName(),
        departamento: territory['departamento']!,
        provincia: territory['provincia']!,
        distrito: widget.district!.trim(),
        latitud: widget.latitude,
        longitud: widget.longitude,
      );
      if (!mounted) return;
      setState(() => _availableEntities = entities);
    } on AiEntityException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loadingEntities = false);
    }
  }

  String? _authorityTypeForEntity(String entityType) {
    switch (entityType) {
      case 'municipalidad':
      case 'municipalidad_distrital':
      case 'municipalidad_provincial':
        return 'municipalidad';
      case 'comisaria_pnp':
        return 'comisaria';
      case 'serenazgo':
        return 'serenazgo';
      case 'autoridad_transporte_urbano':
      case 'empresa_concesionaria_electrica':
        return 'otro';
      default:
        return null;
    }
  }

  void _selectPublicEntity(AiPublicEntity entity) {
    final authorityType = _authorityTypeForEntity(entity.tipo);
    Authority? authority;
    for (final item in _autoridades) {
      if (item.tipo == authorityType && item.isActive) {
        authority = item;
        break;
      }
    }
    if (authority == null) {
      _showMessage('La institución está identificada, pero falta habilitar su tipo receptor en DenuPe.');
      return;
    }
    setState(() {
      _selectedPublicEntity = entity;
      _selectedAuthorityId = authority!.id;
      _entitySuggestion = null;
    });
  }

  void _useAutomaticAssignment() {
    if (_availableEntities.length == 1) {
      final entity = _availableEntities.single;
      _selectPublicEntity(entity);
      if (_selectedPublicEntity?.id == entity.id) {
        _showMessage('DenuPe seleccionó la única institución con competencia verificada: ${entity.nombre}.');
      }
      return;
    }
    setState(() {
      _selectedPublicEntity = null;
      _selectedAuthorityId = null;
      _entitySuggestion = null;
    });
    _showMessage(
      _availableEntities.length > 1
          ? 'Hay varias instituciones posibles. La denuncia pasará a revisión de competencia para evitar una asignación incorrecta.'
          : 'No hay una institución única verificada. La denuncia pasará a revisión de competencia.',
    );
  }

  Authority? get _selectedAuthority {
    final id = _selectedAuthorityId;
    if (id == null) return null;
    for (final authority in _autoridades) {
      if (authority.id == id && authority.isActive) return authority;
    }
    return null;
  }

  String _categoryName() {
    for (final c in widget.categories) {
      if (c.id == widget.categoryId) return c.name;
    }
    return categoryNameFromCache(widget.categoryId);
  }

  Map<String, String>? _territoryForDistrict(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    String normalize(String text) => text.toLowerCase().trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    final district = normalize(value);
    const callaoDistricts = {
      'callao', 'bellavista', 'carmen de la legua reynoso',
      'la perla', 'la punta', 'mi peru', 'ventanilla',
    };
    const limaDistricts = {
      'lima', 'ancon', 'ate', 'barranco', 'brena', 'carabayllo',
      'chaclacayo', 'chorrillos', 'cieneguilla', 'comas', 'el agustino',
      'independencia', 'jesus maria', 'la molina', 'la victoria', 'lince',
      'los olivos', 'lurigancho', 'lurin', 'magdalena del mar', 'miraflores',
      'pachacamac', 'pucusana', 'pueblo libre', 'puente piedra',
      'punta hermosa', 'punta negra', 'rimac', 'san bartolo', 'san borja',
      'san isidro', 'san juan de lurigancho', 'san juan de miraflores',
      'san luis', 'san martin de porres', 'san miguel', 'santa anita',
      'santa maria del mar', 'santa rosa', 'santiago de surco', 'surquillo',
      'villa el salvador', 'villa maria del triunfo',
    };
    if (callaoDistricts.contains(district)) {
      return {'departamento': 'Callao', 'provincia': 'Callao'};
    }
    if (limaDistricts.contains(district)) {
      return {'departamento': 'Lima', 'provincia': 'Lima'};
    }
    return null;
  }

  Future<void> _suggestEntity() async {
    if (_suggestingEntity || _confirming) return;
    final territory = _territoryForDistrict(widget.district);
    if (territory == null) {
      _showMessage(
        'Completa tu distrito en el perfil con un distrito de Lima Metropolitana o Callao para consultar la entidad competente.',
      );
      return;
    }
    setState(() => _suggestingEntity = true);
    // Espera el catálogo local antes de decidir si la recomendación puede
    // convertirse en uno de los tipos receptores que DenuPe almacena.
    if (_autoridades.isEmpty) {
      await _loadAutoridades();
    }
    if (!mounted) return;
    setState(() => _entitySuggestion = null);

    // Mantiene el mismo diálogo de análisis utilizado por la sugerencia de categoría.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _EntitySuggestionLoadingDialog(),
    );

    AiEntitySuggestion? suggestion;
    String? error;
    try {
      suggestion = await AiEntityService().sugerirEntidad(
        categoria: _categoryName(),
        departamento: territory['departamento']!,
        provincia: territory['provincia']!,
        distrito: widget.district!.trim(),
        titulo: widget.title,
        descripcion: widget.description,
        latitud: widget.latitude,
        longitud: widget.longitude,
      );
    } on AiEntityException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo obtener la recomendación. La entidad se determinará con la regla predeterminada de la categoría.';
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _suggestingEntity = false);
      }
    }
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    if (suggestion?.sugerida != true || suggestion?.entidad == null) {
      _showMessage(suggestion?.motivo ?? 'No se encontró una entidad verificable.');
      return;
    }
    setState(() => _entitySuggestion = suggestion);
  }

  void _applyEntitySuggestion() {
    final entity = _entitySuggestion?.entidad;
    if (entity == null) return;
    _selectPublicEntity(entity);
    if (_selectedPublicEntity?.id == entity.id) {
      _showMessage('Se seleccionó ${entity.nombre}.');
    }
  }

  Future<void> _confirm() async {
    final autoridad = _selectedAuthority;
    setState(() => _confirming = true);
    try {
      final complaint = await api.createComplaint(
        categoryId: widget.categoryId,
        title: widget.title,
        description: widget.description,
        address: widget.address,
        latitude: widget.latitude,
        longitude: widget.longitude,
        // Si se aceptó una sugerencia compatible, se guarda el tipo receptor.
        // Si no, el trigger de InsForge aplica la autoridad predeterminada
        // configurada para la categoría.
        autoridadId: autoridad?.id,
        entidadPublicaId: _selectedPublicEntity?.id,
        entidadPublicaNombre: _selectedPublicEntity?.nombre,
      );
      bumpNotificationsTick();
      for (final item in widget.media) {
        try {
          await api.uploadComplaintMedia(
            complaintId: complaint.id,
            bytes: item.bytes,
            filename: item.name,
            contentType: item.contentType,
            mediaType: item.mediaType,
          );
        } catch (_) {
          if (!mounted) return;
          _showMessage('"${item.name}" no se pudo adjuntar');
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on InsforgeException catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _showMessage('Error de conexión');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar denuncia')),
      body: Column(
        children: [
          const Material(
            color: DenuPeColors.surface,
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _ReviewSteps(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final autoridad = _selectedAuthority;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Resumen de la denuncia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildEntityCard(autoridad),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.info_outline, color: DenuPeColors.primary), SizedBox(width: 8), Expanded(child: Text('Al confirmar, tu denuncia será enviada a la entidad correspondiente.'))])),
        const SizedBox(height: 16),
        Row(children: [OutlinedButton(onPressed: _confirming ? null : () => Navigator.of(context).pop(), child: const Text('Editar')), const SizedBox(width: 8), Expanded(child: FilledButton.icon(
          onPressed: _confirming ? null : _confirm,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: _confirming
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Confirmar denuncia'),
        ))]),
        if (autoridad == null) ...[
          const SizedBox(height: 8),
          Text(
            'Si no aceptas una sugerencia compatible, la entidad inicial se '
            'determinará mediante la regla predeterminada de la categoría en DenuPe.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildEntitySuggestionCard(AiEntitySuggestion suggestion) {
    final entity = suggestion.entidad;
    final authorityType =
        entity == null ? null : _authorityTypeForEntity(entity.tipo);
    final canApply = suggestion.sugerida &&
        entity != null &&
        authorityType != null &&
        _autoridades.any(
          (authority) =>
              authority.tipo == authorityType && authority.isActive,
        );
    final isApplied = _selectedPublicEntity?.id == entity?.id;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DenuPeColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DenuPeColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: DenuPeColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Entidad sugerida por IA',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entity?.nombre ?? 'Entidad no disponible',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (entity != null) ...[
            const SizedBox(height: 4),
            Text('Tipo: ' + entity.tipo.replaceAll('_', ' ')),
            if (entity.ambito.isNotEmpty)
              Text('Ámbito: ' + entity.ambito.values.join(' · ')),
            if (entity.direccion != null && entity.direccion!.isNotEmpty)
              Text('Dirección: ' + entity.direccion!),
            if (entity.telefono != null && entity.telefono!.isNotEmpty)
              Text('Teléfono: ' + entity.telefono!),
            if (entity.sitioWeb != null && entity.sitioWeb!.isNotEmpty)
              Text('Web: ' + entity.sitioWeb!),
          ],
          const SizedBox(height: 6),
          Text(suggestion.motivo),
          const SizedBox(height: 6),
          Text(
            isApplied
                ? 'Esta institución está seleccionada para la denuncia.'
                : canApply
                    ? 'Esta es una sugerencia. Tú decides si usarla.'
                    : 'No existe un tipo receptor compatible en el catálogo actual de DenuPe. La recomendación es informativa y no se asignará otra entidad automáticamente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canApply)
                FilledButton.icon(
                  onPressed: (_confirming || _suggestingEntity)
                      ? null
                      : _applyEntitySuggestion,
                  icon: const Icon(Icons.check),
                  label: const Text('Usar sugerencia'),
                ),
              OutlinedButton(
                onPressed: (_confirming || _suggestingEntity)
                    ? null
                    : _suggestEntity,
                child: const Text('Volver a sugerir'),
              ),
              TextButton(
                onPressed: (_confirming || _suggestingEntity)
                    ? null
                    : () => setState(() {
                          _entitySuggestion = null;
                          _selectedAuthorityId = null;
                        }),
                child: const Text('Ignorar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resumen de la denuncia',
                  style: titleStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Categoría', detail: _categoryName()),
            _SummaryRow(label: 'Título', detail: widget.title),
            _SummaryRow(label: 'Descripción', detail: widget.description),
            _SummaryRow(
              label: 'Ubicación',
              detail: (widget.address == null ||
                      widget.address!.trim().isEmpty)
                  ? 'No indicada'
                  : widget.address!.trim(),
            ),
            if (widget.latitude != null && widget.longitude != null)
              _SummaryRow(
                label: 'Coordenadas',
                detail:
                    '${widget.latitude!.toStringAsFixed(6)}, ${widget.longitude!.toStringAsFixed(6)}',
              ),
            const SizedBox(height: 12),
            const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LocationPreview(height: 112),
            if (widget.latitude != null && widget.longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Lat: ${widget.latitude!.toStringAsFixed(5)}, Lng: ${widget.longitude!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text('Evidencias (${widget.media.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.media.isEmpty)
              const Text('No se adjuntaron evidencias.')
            else
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.media.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final media = widget.media[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: media.mediaType == 'image'
                          ? Image.memory(media.bytes, width: 76, height: 76, fit: BoxFit.cover)
                          : Container(width: 76, height: 76,
                              color: DenuPeColors.background,
                              child: const Icon(Icons.videocam_outlined,
                                  color: DenuPeColors.primary)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityCard(Authority? autoridad) {
    final query = _entitySearchQuery.trim().toLowerCase();
    final filtered = _availableEntities.where((entity) {
      if (query.isEmpty) return true;
      return entity.nombre.toLowerCase().contains(query) ||
          entity.tipo.replaceAll('_', ' ').toLowerCase().contains(query) ||
          (entity.ambito['distrito'] ?? '').toLowerCase().contains(query);
    }).toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance_outlined, size: 20,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Entidad responsable',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text(
              '1. Selecciona manualmente una institución disponible para la categoría y ubicación de tu denuncia.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _entitySearchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar institución...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingEntities)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _availableEntities.isEmpty
                      ? 'No hay instituciones con competencia verificada para esta categoría y ubicación. Puedes dejar que DenuPe determine la asignación o consultar la recomendación de IA.'
                      : 'No se encontraron instituciones con ese nombre.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              ...filtered.map((entity) {
                final selected = _selectedPublicEntity?.id == entity.id;
                final district = entity.ambito['distrito'] ?? widget.district ?? '';
                final type = entity.tipo.replaceAll('_', ' ');
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? DenuPeColors.primary : Colors.grey.shade300,
                      width: selected ? 1.5 : 1,
                    ),
                    color: selected ? DenuPeColors.primary.withValues(alpha: 0.06) : null,
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? DenuPeColors.primary : Colors.grey,
                    ),
                    title: Text(entity.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$type · $district'),
                    onTap: (_confirming || _suggestingEntity)
                        ? null
                        : () => _selectPublicEntity(entity),
                  ),
                );
              }),
            if (_selectedPublicEntity != null) ...[
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: DenuPeColors.success, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text('Seleccionada: ${_selectedPublicEntity!.nombre}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_confirming || _suggestingEntity) ? null : _useAutomaticAssignment,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('No estoy seguro, que DenuPe decida'),
              ),
            ),
            const Divider(height: 24),
            Text('2. ¿Necesitas ayuda para elegir?',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Puedes pedir a la inteligencia artificial que analice la denuncia y te sugiera una institución.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_suggestingEntity || _confirming) ? null : _suggestEntity,
                icon: _suggestingEntity
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(_suggestingEntity
                    ? 'Analizando denuncia...'
                    : 'Recomendar entidad con IA'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                ),
              ),
            ),
            if (_entitySuggestion != null) ...[
              const SizedBox(height: 12),
              _buildEntitySuggestionCard(_entitySuggestion!),
            ],
            if (autoridad != null) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Canal de gestión',
                detail: '${autoridad.nombre} (${autoridad.sigla})',
              ),
            ],
          ],
        ),
      ),
    );
  }

}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: detail),
          ],
        ),
      ),
    );
  }
}
class _ReviewSteps extends StatelessWidget {
  const _ReviewSteps();

  @override
  Widget build(BuildContext context) {
    const labels = ['Datos', 'Ubicación', 'Evidencia', 'Revisar'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 3
                        ? DenuPeColors.primary
                        : DenuPeColors.surface,
                    border: Border.all(
                      color: DenuPeColors.primary,
                      width: 1.5,
                    ),
                  ),
                  child: index < 3
                      ? const Icon(Icons.check, size: 15,
                          color: DenuPeColors.primary)
                      : const Text('4', style: TextStyle(
                          color: DenuPeColors.surface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(height: 6),
                Text(labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: index == 3
                        ? DenuPeColors.primary : DenuPeColors.text,
                    fontWeight: index == 3
                        ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(height: 2,
                  child: ColoredBox(color: DenuPeColors.primary)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Diálogo de carga compartiendo el patrón visual de la recomendación de categoría.
class _EntitySuggestionLoadingDialog extends StatelessWidget {
  const _EntitySuggestionLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Sugerencia con IA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Analizando la denuncia y su ubicación'),
            SizedBox(height: 16),
            LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

