import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';
import '../widgets/location_preview.dart';
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
        Text('Resumen de la denuncia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildEntityCard(autoridad),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.info_outline, color: DenuPeColors.primary), SizedBox(width: 8), Expanded(child: Text('Al confirmar, tu denuncia será enviada a la entidad correspondiente.'))])),
        const SizedBox(height: 16),
        Row(children: [OutlinedButton(onPressed: _confirming ? null : () => Navigator.of(context).pop(), child: const Text('Editar')), const SizedBox(width: 8), Expanded(child: FilledButton.icon(
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
        ))]),
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
