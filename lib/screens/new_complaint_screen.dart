import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import '../widgets/location_preview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/app_scope.dart';
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
  static const int _maxMediaBytes = 50 * 1024 * 1024;

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
    _titleFocus.addListener(() { if (_titleFocus.hasFocus) _setStep(0); });
    _descriptionFocus.addListener(() { if (_descriptionFocus.hasFocus) _setStep(0); });
    _addressFocus.addListener(() { if (_addressFocus.hasFocus) _setStep(1); });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([categories(), api.myProfile()]);
      final list = results[0] as List<Category>;
      final profile = results[1] as Profile;
      if (!mounted) return;
      setState(() {
        _cats = list;
        _profile = profile;
        _loading = false;
      });
      if (_categoryId == null && list.isNotEmpty) {
        setState(() => _categoryId = list.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _profileComplete {
    final p = _profile;
    if (p == null) return false;
    return _notBlank(p.fullName) && _notBlank(p.dni) && _notBlank(p.phone);
  }

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;

  Future<void> _editProfile() async {
    final p = _profile;
    if (p == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileEditScreen(profile: p)),
    );
    if (changed == true) {
      _loadCategories();
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
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Permiso de ubicación no concedido');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _showMessage('Ubicación capturada');
    } catch (_) {
      _showMessage('No se pudo obtener la ubicación');
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
      if (bytes.length > _maxMediaBytes) {
        _showMessage('El archivo supera el límite de 50 MB');
        return;
      }
      setState(() {
        _media.add(ComplaintAttachment(
          name: file.name,
          mediaType: mediaType,
          bytes: bytes,
          contentType: _mimeFromName(file.name, mediaType),
        ));
      });
    } catch (_) {
      _showMessage('No se pudo leer el archivo seleccionado');
    }
  }

  void _removeMedia(int index) {
    _setStep(2);
    setState(() => _media.removeAt(index));
  }

  Future<void> _submit() async {
    _setStep(3);
    if (!_formKey.currentState!.validate()) {
      _setStep(0);
      return;
    }
    if (!_profileComplete) {
      _showMessage('Completa tu DNI y teléfono en tu perfil para enviar la denuncia');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      _showMessage('Selecciona una categoría');
      return;
    }
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
    });
    _showMessage('Denuncia enviada. ¡Gracias por reportar!');
    widget.onCreated?.call();
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
                      const Text(
                        'Completa tu DNI y teléfono en tu perfil para '
                        'poder enviar la denuncia.',
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar las categorías'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _loadCategories,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ComplaintSteps(activeStep: _activeStep),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

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
                onChanged: (v) { _setStep(0); setState(() => _categoryId = v); },
                validator: (v) => v == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 16),
              const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(onTap: () => _setStep(1), child: const LocationPreview()),
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
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Foto'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: OutlinedButton(onPressed: () { _formKey.currentState?.reset(); _title.clear(); _description.clear(); _address.clear(); setState(() { _latitude = null; _longitude = null; _media.clear(); }); }, child: const Text('Cancelar'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(
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
                  'Para enviar la denuncia completa tu DNI y teléfono en tu perfil.',
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

String _mimeFromName(String filename, String mediaType) {
  final ext = filename.toLowerCase();
  if (ext.endsWith('.png')) return 'image/png';
  if (ext.endsWith('.gif')) return 'image/gif';
  if (ext.endsWith('.webp')) return 'image/webp';
  if (mediaType == 'image') return 'image/jpeg';
  if (ext.endsWith('.mov')) return 'video/quicktime';
  if (ext.endsWith('.webm')) return 'video/webm';
  if (ext.endsWith('.3gp')) return 'video/3gpp';
  if (ext.endsWith('.m4v')) return 'video/x-m4v';
  if (ext.endsWith('.avi')) return 'video/x-msvideo';
  return 'video/mp4';
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
