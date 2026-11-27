import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import '../widgets/location_preview.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/denupe_api.dart';
import '../services/ai_entity_service.dart';
import '../services/entity_display_name.dart';

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
  String? _resolvedDistrict;
  AiPublicEntity? _selectedPublicEntity;
  String? _selectedTerritorialCategoryCode;
  String _entitySearchQuery = '';
  bool _loadingEntities = false;
  String? _entityCatalogError;
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
    if (widget.latitude == null || widget.longitude == null) {
      if (mounted) {
        setState(() {
          _availableEntities = [];
          _entityCatalogError =
              'Necesitamos la ubicación GPS de la denuncia para identificar tu distrito y mostrar sus opciones.';
        });
      }
      return;
    }
    if (_autoridades.isEmpty) await _loadAutoridades();
    if (!mounted) return;
    setState(() {
      _loadingEntities = true;
      _entityCatalogError = null;
    });
    try {
      final entities = await AiEntityService().listarCatalogoTerritorial(
        latitud: widget.latitude!,
        longitud: widget.longitude!,
      );
      if (!mounted) return;
      setState(() {
        _availableEntities = entities;
        _resolvedDistrict = entities.isEmpty
            ? widget.district
            : entities.first.ambito['distrito'] ?? widget.district;
        _entityCatalogError = null;
      });
    } on AiEntityException catch (e) {
      if (!mounted) return;
      setState(() => _entityCatalogError = _dynamicEntityMessage(e.message));
      _showMessage(_entityCatalogError!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _entityCatalogError =
          'No se pudo consultar el catálogo. Comprueba la conexión y vuelve a intentarlo.');
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
      case 'empresa_saneamiento':
      case 'revision_competencia':
        return 'otro';
      default:
        return null;
    }
  }

  String? _authoritySiglaForEntity(String entityType) {
    switch (entityType) {
      case 'autoridad_transporte_urbano':
      case 'empresa_concesionaria_electrica':
      case 'empresa_saneamiento':
        return 'ESP';
      case 'revision_competencia':
        return 'REV';
      default:
        return null;
    }
  }

  void _selectPublicEntity(AiPublicEntity entity) {
    // Las opciones territoriales son rutas/categorías, no instituciones.
    // Se guardan por separado para no enviar el código de categoría como ID
    // de una entidad pública concreta.
    if (entity.categoriaCode != null) {
      setState(() {
        _selectedTerritorialCategoryCode = entity.categoriaCode;
        _selectedPublicEntity = null;
        _selectedAuthorityId = null;
        _entitySuggestion = null;
      });
      return;
    }

    final authorityType = _authorityTypeForEntity(entity.tipo);
    final authoritySigla = _authoritySiglaForEntity(entity.tipo);
    Authority? authority;
    if (authorityType != null) {
      for (final item in _autoridades) {
        if (item.tipo == authorityType &&
            item.isActive &&
            (authoritySigla == null || item.sigla == authoritySigla)) {
          authority = item;
          break;
        }
      }
    }
    setState(() {
      _selectedPublicEntity = entity;
      _selectedTerritorialCategoryCode = null;
      _selectedAuthorityId = authority?.id;
      _entitySuggestion = null;
    });
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


  String _districtFor(AiPublicEntity? entity) {
    final fromEntity = entity?.ambito['distrito']?.trim();
    if (fromEntity != null && fromEntity.isNotEmpty) return fromEntity;
    final resolved = _resolvedDistrict?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return widget.district?.trim() ?? '';
  }

  String _entityLabel(AiPublicEntity entity) => entityDisplayName(
        reference: entity.entidadReferencia ?? entity.nombre,
        type: entity.tipo,
        district: _districtFor(entity),
      );

  String _districtAwareEntityLabel(String? value, {String? district}) =>
      entityDisplayName(reference: value, district: district);

  String _dynamicEntityMessage(String message) {
    final lower = message.toLowerCase();
    final isGeneric = lower.contains('competente') ||
        lower.contains('correspondiente') ||
        lower.contains('por identificar') ||
        lower.contains('no disponible') ||
        lower.contains('por determinar');
    if (!isGeneric) return message;
    final place = _districtFor(_selectedPublicEntity);
    return place.isEmpty
        ? 'No encontramos una opción verificada.'
        : 'No encontramos una opción verificada en $place.';
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
        'Completa tu distrito en el perfil para ver las opciones disponibles cerca de ti.',
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
      error = 'No se pudo obtener la recomendación. Puedes elegir una opción manualmente.';
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _suggestingEntity = false);
      }
    }
    if (!mounted) return;
    if (error != null) {
      _showMessage(_dynamicEntityMessage(error));
      return;
    }
    if (suggestion?.sugerida != true || suggestion?.entidad == null) {
      _showMessage(_dynamicEntityMessage(
        suggestion?.motivo ?? 'No se encontró una opción verificada.',
      ));
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
        // Se conserva el receptor interno y el identificador exacto de la institución.
        // Si no hay selección, el trigger aplica la bandeja de revisión de competencia.
        autoridadId: autoridad?.id,
        entidadPublicaId: _selectedPublicEntity?.id,
        entidadPublicaNombre: _selectedPublicEntity?.nombre,
        rutaTerritorialCode: _selectedTerritorialCategoryCode,
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
    } on DenupeApiException catch (e) {
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
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.info_outline, color: DenuPeColors.primary), const SizedBox(width: 8), Expanded(child: Text('Al confirmar, tu denuncia se registrará con la opción elegida${_districtFor(null).isEmpty ? '' : ' para ${_districtFor(null)}'} o quedará en análisis interno si no hay una opción válida.'))])),
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
            'Si no eliges una opción, DenuPe derivará la denuncia para análisis interno '
            'y evitará una asignación incorrecta.',
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
    final authoritySigla =
        entity == null ? null : _authoritySiglaForEntity(entity.tipo);
    final canApply = suggestion.sugerida &&
        entity != null &&
        authorityType != null &&
        _autoridades.any(
          (authority) =>
              authority.tipo == authorityType &&
              authority.isActive &&
              (authoritySigla == null || authority.sigla == authoritySigla),
        );
    final isApplied = _selectedPublicEntity?.id == entity?.id;
    final isReviewQueue = entity?.tipo == 'revision_competencia';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DenuPeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DenuPeColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DenuPeColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: DenuPeColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultado de la recomendación',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Asistente de entidades DenuPe',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: DenuPeColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'IA',
                  style: TextStyle(
                    color: DenuPeColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            entity == null
                ? _districtAwareEntityLabel(null, district: _districtFor(null))
                : _entityLabel(entity),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DenuPeColors.text,
                ),
          ),
          if (entity != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _EntityInfoChip(
                  icon: Icons.account_balance_outlined,
                  label: entity.tipo.replaceAll('_', ' '),
                ),
                if (entity.ambito.isNotEmpty)
                  _EntityInfoChip(
                    icon: Icons.location_on_outlined,
                    label: entity.ambito.values.join(' · '),
                  ),
              ],
            ),
            if (entity.direccion != null && entity.direccion!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _EntityDetailLine(
                icon: Icons.place_outlined,
                value: entity.direccion!,
              ),
            ],
            if (entity.telefono != null && entity.telefono!.isNotEmpty)
              _EntityDetailLine(
                icon: Icons.phone_outlined,
                value: entity.telefono!,
              ),
            if (entity.sitioWeb != null && entity.sitioWeb!.isNotEmpty)
              _EntityDetailLine(
                icon: Icons.language_outlined,
                value: entity.sitioWeb!,
              ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DenuPeColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Por qué se recomienda?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion.motivo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isReviewQueue
                ? 'Este es un destino interno de DenuPe, no una institución pública externa. El equipo revisará el caso y determinará qué organismo debe recibir la denuncia.'
                : isApplied
                    ? 'Esta institución está seleccionada para tu denuncia.'
                    : canApply
                        ? 'Revisa la información. Tú decides si deseas utilizar esta institución.'
                        : 'La recomendación es informativa porque no existe un tipo receptor compatible en el catálogo actual de DenuPe.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canApply)
                FilledButton.icon(
                  onPressed: (_confirming || _suggestingEntity)
                      ? null
                      : _applyEntitySuggestion,
                  icon: Icon(isApplied ? Icons.check_circle : Icons.check),
                  label: Text(isApplied ? 'Sugerencia aplicada' : 'Usar sugerencia'),
                ),
              OutlinedButton.icon(
                onPressed: (_confirming || _suggestingEntity)
                    ? null
                    : _suggestEntity,
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a sugerir'),
              ),
              TextButton(
                onPressed: (_confirming || _suggestingEntity)
                    ? null
                    : () => setState(() {
                          _entitySuggestion = null;
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

  String _selectedTerritorialOptionName() {
    for (final entity in _availableEntities) {
      if (entity.categoriaCode == _selectedTerritorialCategoryCode) {
        return _districtAwareEntityLabel(
          entity.entidadReferencia,
          district: entity.ambito['distrito'] ?? widget.district,
        );
      }
    }
    return _districtAwareEntityLabel(null, district: widget.district);
  }

  Widget _buildEntityCard(Authority? autoridad) {
    final channelLabel = _selectedPublicEntity == null
        ? _districtAwareEntityLabel(autoridad?.nombre, district: _districtFor(null))
        : _entityLabel(_selectedPublicEntity!);
    final query = _entitySearchQuery.trim().toLowerCase();
    final filtered = _availableEntities.where((entity) {
      if (query.isEmpty) return true;
      return entity.nombre.toLowerCase().contains(query) ||
          (entity.entidadReferencia ?? '').toLowerCase().contains(query) ||
          entity.tipo.replaceAll('_', ' ').toLowerCase().contains(query) ||
          (entity.ambito['distrito'] ?? '').toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DenuPeColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_outlined,
                        color: DenuPeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _districtFor(null).isEmpty
                                ? '1. Opciones cerca de ti'
                                : '1. Opciones en ${_districtFor(null)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _districtFor(null).isEmpty
                                ? 'Selecciona el canal de atención disponible para tu ubicación.'
                                : 'Selecciona el canal de atención disponible para ${_districtFor(null)}.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) =>
                      setState(() => _entitySearchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar institución...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingEntities)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _entityCatalogError ??
                              (_availableEntities.isEmpty
                                  ? _districtFor(null).isEmpty
                                      ? 'El catálogo no devolvió opciones para tu ubicación. Comprueba la ubicación GPS o vuelve a consultar.'
                                      : 'El catálogo no devolvió opciones para ${_districtFor(null)}. Comprueba la ubicación GPS o vuelve a consultar.'
                                  : 'No se encontraron instituciones con ese nombre.'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_entityCatalogError != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _loadingEntities
                                  ? null
                                  : _loadManualEntities,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar catálogo'),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((entity) {
                    final selected = entity.categoriaCode != null
                        ? _selectedTerritorialCategoryCode == entity.categoriaCode
                        : _selectedPublicEntity?.id == entity.id;
                    final district = _districtFor(entity);
                    final displayName = _entityLabel(entity);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? DenuPeColors.primary.withValues(alpha: 0.055)
                            : DenuPeColors.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: selected
                              ? DenuPeColors.primary
                              : Colors.grey.shade300,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: (_confirming || _suggestingEntity)
                            ? null
                            : () => _selectPublicEntity(entity),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: DenuPeColors.primary.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.account_balance_outlined,
                                  color: DenuPeColors.primary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: DenuPeColors.text,
                                          ),
                                    ),
                                    if (district.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Distrito de $district',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: selected
                                    ? DenuPeColors.primary
                                    : Colors.grey.shade400,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                if (_selectedPublicEntity != null || _selectedTerritorialCategoryCode != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DenuPeColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: DenuPeColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Opción seleccionada: ${_selectedPublicEntity == null ? _selectedTerritorialOptionName() : _entityLabel(_selectedPublicEntity!)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (autoridad != null) ...[
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Canal de gestión',
                    detail: '$channelLabel (${autoridad.sigla})',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: DenuPeColors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DenuPeColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        color: DenuPeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _districtFor(null).isEmpty
                                ? '2. ¿Necesitas ayuda para elegir?'
                                : '2. ¿Ayuda para elegir en ${_districtFor(null)}?',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _districtFor(null).isEmpty
                                ? 'La IA solo buscará una opción específica cuando pulses «Sugerir entidad», usando la categoría, el contenido y tu ubicación.'
                                : 'La IA solo buscará una opción específica cuando pulses «Sugerir entidad», usando la categoría, el contenido y tu ubicación en ${_districtFor(null)}.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_suggestingEntity || _confirming) ? null : _suggestEntity,
                    icon: _suggestingEntity
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _suggestingEntity
                          ? 'Analizando denuncia...'
                          : 'Sugerir entidad',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: DenuPeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_entitySuggestion != null) ...[
                  const SizedBox(height: 14),
                  _buildEntitySuggestionCard(_entitySuggestion!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

}


class _EntityInfoChip extends StatelessWidget {
  const _EntityInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: DenuPeColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DenuPeColors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _EntityDetailLine extends StatelessWidget {
  const _EntityDetailLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 7),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
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

