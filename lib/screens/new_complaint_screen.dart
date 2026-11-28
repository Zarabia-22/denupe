import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import '../widgets/location_preview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/ai_category_service.dart';
import '../services/friendly_error.dart';
import 'complaint_confirmation_screen.dart';
import 'profile_edit_screen.dart';

class NuevaDenunciaScreen extends StatefulWidget {
  const NuevaDenunciaScreen({super.key, this.onCreated});

  final VoidCallback? onCreated;

  @override
  State<NuevaDenunciaScreen> createState() => _NuevaDenunciaScreenState();
}

class _NuevaDenunciaScreenState extends State<NuevaDenunciaScreen> {
  static const int _maxMedia = 5;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxVideoBytes = 50 * 1024 * 1024;
  static const int _maxTotalBytes = 120 * 1024 * 1024;
  static const Map<String, int> _allowedMimeBytes = {
    'image/jpeg': _maxImageBytes,
    'image/png': _maxImageBytes,
    'image/webp': _maxImageBytes,
    'video/mp4': _maxVideoBytes,
    'video/quicktime': _maxVideoBytes,
  };

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _picker = ImagePicker();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _addressFocus = FocusNode();
  int _activeStep = 0;

  void _setStep(int step) {
    if (_activeStep != step && mounted) setState(() => _activeStep = step);
  }
  String? _categoryId;
  String? _suggestedCategoryId;
  bool _suggestingAi = false;
  String? _error;
  bool _loading = false;
  double? _latitude;
  double? _longitude;
  List<Category> _cats = [];
  Profile? _profile;
  final List<ComplaintAttachment> _media = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _title.addListener(_invalidateSuggestion);
    _description.addListener(_invalidateSuggestion);
    _titleFocus.addListener(() { if (_titleFocus.hasFocus) _setStep(0); });
    _descriptionFocus.addListener(() { if (_descriptionFocus.hasFocus) _setStep(0); });
    _addressFocus.addListener(() { if (_addressFocus.hasFocus) _setStep(1); });
  }

  @override
  void dispose() {
    _title.removeListener(_invalidateSuggestion);
    _description.removeListener(_invalidateSuggestion);
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    List<Category>? list;
    String? categoryError;
    try {
      list = await categories();
    } catch (e) {
      categoryError = friendlyError(e);
    }
    Profile? profile;
    String? profileError;
    try {
      profile = await api.myProfile();
    } catch (e) {
      profileError = friendlyError(e);
    }
    if (!mounted) return;
    setState(() {
      if (list != null) _cats = list;
      if (profile != null) _profile = profile;
      _loading = false;
      _error = categoryError ?? profileError;
    });
    if (_categoryId == null && _cats.isNotEmpty) {
      setState(() => _categoryId = _cats.first.id);
    }
  }

  bool get _profileComplete {
    final p = _profile;
    if (p == null) return false;
    return _notBlank(p.fullName) &&
        _isValidPeruvianDni(p.dni ?? '') &&
        _notBlank(p.phone);
  }

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;

  static bool _isValidPeruvianDni(String value) =>
      RegExp(r'^\d{8}$').hasMatch(value.trim());

  List<String> get _missingProfileFields {
    final p = _profile;
    final missing = <String>[];
    if (p == null || !_notBlank(p.fullName)) missing.add('nombre');
    if (p == null || !_isValidPeruvianDni(p.dni ?? '')) missing.add('DNI válido');
    if (p == null || !_notBlank(p.phone)) missing.add('teléfono');
    return missing;
  }

  Future<void> _editProfile() async {
    final p = _profile;
    if (p == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileEditScreen(profile: p)),
    );
    if (changed == true && mounted) {
      await _loadCategories();
    }
  }

  Future<void> _captureLocation() async {
    _setStep(1);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('El servicio de ubicación está desactivado');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('El permiso de ubicación está desactivado permanentemente. Actívalo desde ajustes.'),
              action: SnackBarAction(
                label: 'Ajustes',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        return;
      }
      if (permission == LocationPermission.denied) {
        _showMessage('Permiso de ubicación no concedido');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _showMessage('Ubicación capturada');
    } catch (e) {
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _pickImage() async {
    _setStep(2);
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    await _addMedia(file, 'image');
  }

  Future<void> _pickVideo() async {
    _setStep(2);
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    await _addMedia(file, 'video');
  }

  Future<void> _addMedia(XFile? file, String mediaType) async {
    if (file == null || !mounted) return;
    if (_media.length >= _maxMedia) {
      _showMessage('Máximo $_maxMedia adjuntos por denuncia');
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final contentType = _normalizeMime(file.mimeType, file.name);
      final maxBytes = _allowedMimeBytes[contentType];
      if (maxBytes == null) {
        _showMessage('Formato no permitido. Usa JPG, PNG, WEBP, MP4 o MOV.');
        return;
      }
      if (bytes.length > maxBytes) {
        _showMessage('El archivo supera el límite de ${maxBytes ~/ (1024 * 1024)} MB');
        return;
      }
      final totalBytes = _media.fold<int>(bytes.length, (sum, item) => sum + item.bytes.length);
      if (totalBytes > _maxTotalBytes) {
        _showMessage('El total de adjuntos supera el límite de ${_maxTotalBytes ~/ (1024 * 1024)} MB');
        return;
      }
      setState(() {
        _media.add(ComplaintAttachment(
          name: file.name,
          mediaType: contentType.startsWith('image/') ? 'image' : 'video',
          bytes: bytes,
          contentType: contentType,
        ));
      });
    } catch (e) {
      _showMessage(friendlyError(e));
    }
  }

  void _removeMedia(int index) {
    _setStep(2);
    setState(() => _media.removeAt(index));
  }

  bool get _hasDraftData =>
      _title.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _address.text.trim().isNotEmpty ||
      _latitude != null ||
      _longitude != null ||
      _media.isNotEmpty;

  Future<void> _cancelForm() async {
    if (!_hasDraftData) {
      _formKey.currentState?.reset();
      setState(() {});
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar denuncia'),
        content: const Text('Se perderán los datos ingresados. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _formKey.currentState?.reset();
    _title.clear();
    _description.clear();
    _address.clear();
    setState(() {
      _latitude = null;
      _longitude = null;
      _media.clear();
      _suggestedCategoryId = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _setStep(0);
      return;
    }
    if (!_profileComplete) {
      final missing = _missingProfileFields;
      _showMessage(missing.isEmpty
          ? 'Completa tu perfil para enviar la denuncia'
          : 'Completa tu perfil para denunciar: ${missing.join(', ')}');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      _showMessage('Selecciona una categoría');
      return;
    }
    _setStep(3);
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplaintConfirmationScreen(
          categoryId: categoryId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          media: List<ComplaintAttachment>.of(_media),
          categories: _cats,
          district: _profile?.district,
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    bumpNotificationsTick();
    _media.clear();
    _title.clear();
    _description.clear();
    _address.clear();
    setState(() {
      _latitude = null;
      _longitude = null;
      _suggestedCategoryId = null;
    });
    _showMessage('Denuncia enviada. ¡Gracias por reportar!');
    widget.onCreated?.call();
  }

  void _invalidateSuggestion() {
    // Una predicción anterior ya no corresponde al texto editado.
    if (_suggestedCategoryId != null && mounted) {
      setState(() => _suggestedCategoryId = null);
    }
  }

  static String _normalizeCategory(String value) {
    return value.toLowerCase().trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  Category? _matchingCategory(String label) {
    final prediction = _normalizeCategory(label);
    final aliases = <String, List<String>>{
      'alumbrado': ['alumbrado', 'iluminacion publica'],
      'limpieza': ['limpieza', 'residuos solidos', 'basura'],
      'seguridad': ['seguridad', 'serenazgo', 'delincuencia'],
      'ruido': ['ruido', 'contaminacion sonora'],
    };
    final keywords = aliases[prediction] ?? <String>[prediction];
    final matches = _cats.where((c) {
      final name = _normalizeCategory(c.name);
      final code = _normalizeCategory(c.code);
      return name == prediction || code == prediction ||
          keywords.any((keyword) =>
              name == keyword || code == keyword ||
              name.contains(keyword) || code.contains(keyword));
    }).toList();

    // Si hay dos categorías parecidas, no elegimos una arbitrariamente.
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _showAiLoadingDialog() async {
    if (_suggestingAi) return;
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.length < 5 || description.length < 10) {
      _showMessage('Completa el título y la descripción antes de solicitar una sugerencia.');
      return;
    }
    if (_cats.isEmpty) {
      _showMessage('No hay categorías disponibles para sugerir.');
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() {
      _suggestingAi = true;
      _suggestedCategoryId = null;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AiSuggestionLoadingDialog(),
    );

    AiCategorySuggestion? result;
    String? error;
    try {
      result = await AiCategoryService().sugerirCategoria(
        titulo: title,
        descripcion: description,
      );
    } on AiCategoryException catch (e) {
      error = e.message;
    } catch (e) {
      error = friendlyError(e);
    } finally {
      if (navigator.mounted) navigator.pop();
      if (mounted) setState(() => _suggestingAi = false);
    }
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    if (title != _title.text.trim() || description != _description.text.trim()) {
      _showMessage('El texto cambió durante el análisis. Solicita una nueva sugerencia.');
      return;
    }
    if (result?.sugerida != true || result?.categoria == null) {
      _showMessage(result?.motivo ?? 'La IA no encontró una categoría. Elige una manualmente.');
      return;
    }
    final category = _matchingCategory(result!.categoria!);
    if (category == null) {
      _showMessage('La categoría sugerida no coincide con una única categoría disponible. Selecciónala manualmente.');
      return;
    }
    setState(() => _suggestedCategoryId = category.id);
  }

  void _acceptAiSuggestion() {
    final suggestion = _suggestedCategoryId;
    if (suggestion == null) return;
    setState(() {
      _categoryId = suggestion;
      _suggestedCategoryId = null;
    });
    _showMessage('Categoría sugerida seleccionada');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildContactSection() {
    final p = _profile!;
    final email = api.currentUser?.email;
    final complete = _profileComplete;
    return [
      Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Datos del denunciante',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Se toman automáticamente de tu perfil.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              _ContactRow(label: 'Nombre', value: p.fullName),
              _ContactRow(label: 'DNI', value: p.dni),
              _ContactRow(label: 'Correo', value: email),
              _ContactRow(label: 'Teléfono', value: p.phone),
                if (!complete) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DenuPeColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: DenuPeColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _missingProfileFields.isEmpty
                              ? 'Completa tu perfil para poder enviar la denuncia.'
                              : 'Completa tu perfil para poder enviar la denuncia: ${_missingProfileFields.join(', ')}.',
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _editProfile,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Actualizar mi perfil'),
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildMediaRow() {
    return [
      SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: _media.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _media[index];
            return _PendingMediaTile(
              media: item,
              onRemove: () => _removeMedia(index),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final hasCategories = _cats.isNotEmpty;
      final hasProfile = _profile != null;
      final title = !hasCategories && !hasProfile
          ? 'No se pudieron cargar los datos necesarios'
          : !hasCategories
              ? 'No se pudieron cargar las categorías'
              : 'No se pudo cargar tu perfil';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadCategories,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        // El indicador permanece visible mientras el formulario se desplaza.
        Material(
          color: DenuPeColors.surface,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _ComplaintSteps(activeStep: _activeStep),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildContactSection(),
              TextFormField(
                controller: _title,
                focusNode: _titleFocus,
                decoration: const InputDecoration(labelText: 'Título de la denuncia *', hintText: 'Escribe un título breve', prefixIcon: Icon(Icons.edit_outlined)),
                maxLength: 100,
                validator: (v) => v == null || v.trim().length < 5 ? 'Escribe al menos 5 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                focusNode: _descriptionFocus,
                decoration: const InputDecoration(labelText: 'Descripción *', hintText: 'Describe la situación...', alignLabelWithHint: true, prefixIcon: Icon(Icons.description_outlined)),
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                validator: (v) => v == null || v.trim().length < 10 ? 'Escribe al menos 10 caracteres' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_categoryId),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _cats
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onTap: () => _setStep(0),
                onChanged: (v) { _setStep(0); setState(() { _categoryId = v; _suggestedCategoryId = null; }); },
                validator: (v) => v == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 12),
              // HU-IA01: sugerencia real mediante el servicio Python + FastAPI.
              // La categoría no cambia hasta que el usuario la acepte.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _suggestingAi ? null : _showAiLoadingDialog,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Sugerir categoría con IA'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                  ),
                ),
              ),
              if (_suggestedCategoryId != null) ...[
                const SizedBox(height: 12),
                Container(
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
                          Icon(Icons.auto_awesome_outlined,
                              color: DenuPeColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Categoría sugerida por IA',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cats
                            .where((c) => c.id == _suggestedCategoryId)
                            .map((c) => c.name)
                            .firstOrNull ?? 'Categoría no disponible',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Esta es una sugerencia. Tú decides si usarla.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _acceptAiSuggestion,
                            icon: const Icon(Icons.check),
                            label: const Text('Usar sugerencia'),
                          ),
                          OutlinedButton(
                            onPressed: _showAiLoadingDialog,
                            child: const Text('Volver a sugerir'),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _suggestedCategoryId = null,
                            ),
                            child: const Text('Ignorar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _setStep(1),
                child: LocationPreview(
                  latitude: _latitude,
                  longitude: _longitude,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _captureLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
              ),
              if (_latitude != null && _longitude != null)
                Text('Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                focusNode: _addressFocus,
                decoration: const InputDecoration(
                  labelText: 'Dirección referencial (opcional)',
                  hintText: 'Ej. Av. Los Olivos 123',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Text('Adjuntos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Añade fotos o videos para describir mejor el problema.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              if (_media.isNotEmpty) ..._buildMediaRow(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: OutlinedButton(onPressed: _cancelForm, child: const Text('Cancelar'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(
                onPressed: !_profileComplete ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Siguiente'),
              ))]),
              if (!_profileComplete) ...[
                const SizedBox(height: 8),
                Text(
                  _missingProfileFields.isEmpty
                      ? 'Para enviar la denuncia completa tu perfil.'
                      : 'Para enviar la denuncia completa tu perfil: ${_missingProfileFields.join(', ')}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Diálogo de carga real; se cierra cuando termina la solicitud HTTP.
class _AiSuggestionLoadingDialog extends StatelessWidget {
  const _AiSuggestionLoadingDialog();

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
            Text('Analizando título y descripción'),
            SizedBox(height: 16),
            LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Archivo elegido que se subirá junto con la denuncia.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              has ? value!.trim() : 'No registrado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: has ? null : Colors.orange.shade800,
                fontStyle: has ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingMediaTile extends StatelessWidget {
  const _PendingMediaTile({required this.media, required this.onRemove});

  final ComplaintAttachment media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget preview = media.mediaType == 'image'
        ? Image.memory(media.bytes, fit: BoxFit.cover, width: 96, height: 88)
        : Container(
            width: 96,
            height: 88,
            color: Colors.black87,
            child: const Icon(Icons.videocam, color: Colors.white, size: 32),
          );
    return SizedBox(
      width: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: preview,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeMime(String? mimeType, String filename) {
  final mime = (mimeType ?? '').toLowerCase().split(';').first.trim();
  if (mime.isNotEmpty) return mime;
  final ext = filename.toLowerCase();
  if (ext.endsWith('.png')) return 'image/png';
  if (ext.endsWith('.webp')) return 'image/webp';
  if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
  if (ext.endsWith('.mov')) return 'video/quicktime';
  if (ext.endsWith('.mp4') || ext.endsWith('.m4v')) return 'video/mp4';
  return '';
}
class _ComplaintSteps extends StatelessWidget {
  const _ComplaintSteps({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['Datos', 'Ubicación', 'Evidencia', 'Revisar'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == activeStep
                        ? DenuPeColors.primary
                        : DenuPeColors.surface,
                    border: Border.all(
                      color: index <= activeStep
                          ? DenuPeColors.primary
                          : DenuPeColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Text('${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: index == activeStep
                          ? FontWeight.bold : FontWeight.normal,
                      color: index == activeStep
                          ? DenuPeColors.surface : DenuPeColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: index == activeStep
                        ? DenuPeColors.primary : DenuPeColors.text,
                    fontWeight: index == activeStep
                        ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  color: index < activeStep
                      ? DenuPeColors.primary
                      : DenuPeColors.border,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
