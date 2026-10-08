import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  double? _latitude;
  double? _longitude;
  List<Category> _cats = [];

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _showMessage('Selecciona una categoría');
      return;
    }
    setState(() => _submitting = true);
    try {
      await api.createComplaint(
        categoryId: _categoryId!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      bumpNotificationsTick();
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