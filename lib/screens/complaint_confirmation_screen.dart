import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import '../models.dart';
import '../services/app_scope.dart';

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
  });

  final String categoryId;
  final String title;
  final String description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<ComplaintAttachment> media;
  final List<Category> categories;

  @override
  State<ComplaintConfirmationScreen> createState() =>
      _ComplaintConfirmationScreenState();
}

class _ComplaintConfirmationScreenState
    extends State<ComplaintConfirmationScreen> {
  List<Authority> _autoridades = [];
  bool _loading = true;
  String? _error;
  String? _tipo = 'municipalidad';
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _loadAutoridades();
  }

  Future<void> _loadAutoridades() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await authorities();
      if (!mounted) return;
      setState(() {
        _autoridades = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Authority? get _autoridadDeTipo {
    final tipo = _tipo;
    if (tipo == null) return null;
    for (final a in _autoridades) {
      if (a.tipo == tipo && a.isActive) return a;
    }
    return null;
  }

  String _categoryName() {
    for (final c in widget.categories) {
      if (c.id == widget.categoryId) return c.name;
    }
    return categoryNameFromCache(widget.categoryId);
  }

  Future<void> _confirm() async {
    final autoridad = _autoridadDeTipo;
    if (autoridad == null) {
      _showMessage('No hay una entidad disponible para este tipo');
      return;
    }
    setState(() => _confirming = true);
    try {
      final complaint = await api.createComplaint(
        categoryId: widget.categoryId,
        title: widget.title,
        description: widget.description,
        address: widget.address,
        latitude: widget.latitude,
        longitude: widget.longitude,
        autoridadId: autoridad.id,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
            const Text('No se pudieron cargar las entidades'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _loadAutoridades,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final autoridad = _autoridadDeTipo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildEntityCard(autoridad),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: (_confirming || autoridad == null) ? null : _confirm,
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
        ),
        if (autoridad == null) ...[
          const SizedBox(height: 8),
          Text(
            'No hay una entidad disponible para el tipo seleccionado.',
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
            _SummaryRow(
              label: 'Adjuntos',
              detail: widget.media.isEmpty
                  ? 'Ninguno'
                  : '${widget.media.length} archivo(s)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityCard(Authority? autoridad) {
    final tipTypes = const [
      ('municipalidad', Icons.location_city, 'Municipalidad'),
      ('comisaria', Icons.local_police_outlined, 'Comisaría'),
      ('serenazgo', Icons.shield_outlined, 'Serenazgo'),
    ];
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
                  Icons.account_balance_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Entidad asignada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'La denuncia será atendida por el tipo de entidad que selecciones.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: tipTypes.map((entry) {
                final (tipo, icon, label) = entry;
                return ChoiceChip(
                  selected: _tipo == tipo,
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  onSelected: _confirming
                      ? null
                      : (_) => setState(() => _tipo = tipo),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Entidad',
              detail: autoridad == null
                  ? 'No disponible'
                  : '${autoridad.nombre} (${autoridad.sigla})',
            ),
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