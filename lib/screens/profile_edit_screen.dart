import 'package:flutter/material.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/friendly_error.dart';

/// Formulario de edición del perfil propio (nombre, DNI, teléfono, distrito).
/// Devuelve `true` al pop si hubo cambios guardados.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dni;
  late final TextEditingController _phone;
  late final TextEditingController _district;
  List<String> _districts = [];
  bool _loading = false;
  bool _loadingDistricts = true;
  String? _districtError;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.fullName ?? '');
    _dni = TextEditingController(text: p.dni ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _district = TextEditingController(text: p.district ?? '');
    _loadDistricts();
  }

  @override
  void dispose() {
    _name.dispose();
    _dni.dispose();
    _phone.dispose();
    _district.dispose();
    super.dispose();
  }

  String _normalizeDistrictKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ');

  String? _catalogDistrict(String value) {
    final key = _normalizeDistrictKey(value);
    if (key.isEmpty) return null;
    for (final district in _districts) {
      if (_normalizeDistrictKey(district) == key) return district;
    }
    return null;
  }

  Future<void> _loadDistricts() async {
    if (!mounted) return;
    setState(() {
      _loadingDistricts = true;
      _districtError = null;
    });
    try {
      final rows = await api.districts(limit: 2000);
      if (!mounted) return;
      setState(() {
        _districts = rows
            .map((row) => (row['distrito'] ??
                        row['district'] ??
                        row['name'] ??
                        row['nombre'] ??
                        '')
                    .toString()
                    .trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _loadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _districtError = friendlyError(e);
        _loadingDistricts = false;
      });
    }
  }

  static bool _isValidPeruvianDni(String value) =>
      RegExp(r'^\d{8}$').hasMatch(value.trim());

  String? _resolveDistrict(String value) {
    if (value.isEmpty) return '';
    final current = widget.profile.district?.trim() ?? '';
    if (current.isNotEmpty &&
        _normalizeDistrictKey(value) == _normalizeDistrictKey(current)) {
      return current;
    }
    return _catalogDistrict(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final district = _resolveDistrict(_district.text.trim());
    if (district == null) {
      _showMessage('Selecciona un distrito del catálogo o conserva el actual');
      return;
    }
    setState(() => _loading = true);
    try {
      await api.updateProfile(
        fullName: _name.text.trim(),
        dni: _dni.text.trim(),
        phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
        district: district,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dni,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'DNI *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        counterText: '',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Ingresa tu DNI';
                        if (value.length != 8 || int.tryParse(value) == null) {
                          return 'El DNI debe tener 8 dígitos';
                        }
                        if (!_isValidPeruvianDni(value)) {
                          return 'Ingresa un DNI válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.isEmpty) return 'Ingresa tu teléfono';
                        if (digits.length < 6 || digits.length > 15) {
                          return 'Ingresa un teléfono válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _district.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final query =
                            _normalizeDistrictKey(textEditingValue.text);
                        if (query.isEmpty) return const Iterable<String>.empty();
                        return _districts.where((district) =>
                            _normalizeDistrictKey(district).contains(query));
                      },
                      onSelected: (selection) {
                        setState(() => _district.text = selection);
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (value) => _district.text = value,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Distrito (opcional)',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            suffixIcon: _loadingDistricts
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Recargar distritos',
                                    onPressed: _loadDistricts,
                                    icon: const Icon(Icons.refresh),
                                  ),
                            helperText: _districtError == null
                                ? 'Selecciona un distrito del catálogo o conserva el actual.'
                                : null,
                            helperMaxLines: 2,
                            errorText: _districtError,
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return null;
                            if (_resolveDistrict(value) == null) {
                              return 'Selecciona un distrito del catálogo o conserva el actual';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}