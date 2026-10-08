import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import '../models.dart';
import '../services/app_scope.dart';

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
  String? _categoryId;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  double? _latitude;
  double? _longitude;
  List<Category> _cats = [];
  final List<_PendingMedia> _media = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final list = await categories();
      if (!mounted) return;
      setState(() {
        _cats = list;
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

  Future<void> _captureLocation() async {
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
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    await _addMedia(file, 'image');
  }

  Future<void> _pickVideo() async {
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
        _media.add(_PendingMedia(
          xfile: file,
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
    setState(() => _media.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _showMessage('Selecciona una categoría');
      return;
    }
    setState(() => _submitting = true);
    try {
      final complaint = await api.createComplaint(
        categoryId: _categoryId!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      bumpNotificationsTick();
      final pending = List<_PendingMedia>.of(_media);
      _media.clear();
      if (mounted) setState(() {});
      for (final item in pending) {
        try {
          await api.uploadComplaintMedia(
            complaintId: complaint.id,
            bytes: item.bytes,
            filename: item.xfile.name,
            contentType: item.contentType,
            mediaType: item.mediaType,
          );
        } catch (_) {
          if (!mounted) return;
          _showMessage('"${item.xfile.name}" no se pudo adjuntar');
        }
      }
      if (!mounted) return;
      _showMessage('Denuncia enviada. ¡Gracias por reportar!');
      _title.clear();
      _description.clear();
      _address.clear();
      setState(() {
        _latitude = null;
        _longitude = null;
      });
      widget.onCreated?.call();
    } on InsforgeException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Error de conexión');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _cats
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 120,
                validator: (v) =>
                    (v == null || v.trim().length < 5)
                        ? 'Describe el problema en pocas palabras'
                        : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                validator: (v) =>
                    (v == null || v.trim().length < 10)
                        ? 'Da más detalles (mínimo 10 caracteres)'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Dirección o referencia (opcional)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _captureLocation,
                icon: const Icon(Icons.my_location),
                label: _latitude != null && _longitude != null
                    ? Text(
                        'Ubicación: '
                        '${_latitude!.toStringAsFixed(5)}, '
                        '${_longitude!.toStringAsFixed(5)}')
                    : const Text('Usar mi ubicación'),
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Enviar denuncia'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Archivo elegido que se subirá junto con la denuncia.
class _PendingMedia {
  _PendingMedia({
    required this.xfile,
    required this.mediaType,
    required this.bytes,
    required this.contentType,
  });

  final XFile xfile;
  final String mediaType;
  final Uint8List bytes;
  final String contentType;
}

class _PendingMediaTile extends StatelessWidget {
  const _PendingMediaTile({required this.media, required this.onRemove});

  final _PendingMedia media;
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