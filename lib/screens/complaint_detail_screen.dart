import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/complaint_realtime.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Complaint? _complaint;
  List<StatusHistory> _history = [];
  List<ComplaintMedia> _media = [];
  List<Authority> _autoridades = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    realtime.subscribeComplaint(widget.complaintId, _onStatusChanged);
    _load();
  }

  @override
  void dispose() {
    realtime.unsubscribeComplaint(widget.complaintId);
    super.dispose();
  }

  void _onStatusChanged(StatusChangedEvent event) {
    if (event.complaintId != widget.complaintId) return;
    bumpNotificationsTick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('La denuncia cambió a "${statusLabel(event.status)}"'),
      ),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.complaintById(widget.complaintId),
        api.complaintHistory(widget.complaintId),
        api.complaintMedia(widget.complaintId),
        authorities(),
      ]);
      if (!mounted) return;
      setState(() {
        _complaint = results[0] as Complaint?;
        _history = results[1] as List<StatusHistory>;
        _media = results[2] as List<ComplaintMedia>;
        _autoridades = results[3] as List<Authority>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denuncia')),
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
            const Text('No se pudo cargar la denuncia'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final complaint = _complaint;
    if (complaint == null) {
      return const Center(child: Text('Denuncia no encontrada'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(status: complaint.status),
          const SizedBox(height: 16),
          Text(
            complaint.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(complaint.description, style: const TextStyle(fontSize: 15)),
          if (_media.isNotEmpty) ..._buildMediaSection(),
          const Divider(height: 32),
          _InfoRow(label: 'Categoría', detail: _categoryLabel(complaint.categoryId)),
          _InfoRow(label: 'Entidad asignada', detail: _authorityLabel(complaint.autoridadId)),
          if (complaint.address != null && complaint.address!.isNotEmpty)
            _InfoRow(label: 'Ubicación', detail: complaint.address!),
          if (complaint.latitude != null && complaint.longitude != null)
            _InfoRow(
              label: 'Coordenadas',
              detail:
                  '${complaint.latitude!.toStringAsFixed(6)}, ${complaint.longitude!.toStringAsFixed(6)}',
            ),
          _InfoRow(
            label: 'Fecha',
            detail:
                '${_fmt(complaint.createdAt)} (actualizada: ${_fmt(complaint.updatedAt)})',
          ),
          const Divider(height: 32),
          Text('Seguimiento', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Text('Esta denuncia aún no tiene actualizaciones.')
          else
            ..._history.map((h) => _HistoryTile(entry: h)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _categoryLabel(String? id) => categoryNameFromCache(id);

  String _authorityLabel(String? id) => authorityNameOf(_autoridades, id);

  List<Widget> _buildMediaSection() {
    return [
      const SizedBox(height: 16),
      Text('Evidencias', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _media.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _media[index];
            return _MediaTile(
              media: item,
              onDelete: () => _confirmDeleteMedia(item),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _confirmDeleteMedia(ComplaintMedia media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar adjunto'),
        content: const Text('¿Seguro que quieres eliminar este adjunto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.deleteComplaintMedia(media);
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el adjunto')),
      );
    }
  }
}

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: color),
          const SizedBox(width: 8),
          Text(
            'Estado: ${statusLabel(status)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  const _MediaTile({required this.media, this.onDelete});

  final ComplaintMedia media;
  final VoidCallback? onDelete;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    setState(() => _url = null);
    try {
      final url = await api.complaintMediaSignedUrl(widget.media.storageKey);
      if (!mounted) return;
      setState(() => _url = url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _openVideo() async {
    final url = _url;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openImage() {
    final url = _url;
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (_failed) {
      preview = Container(
        width: 120,
        height: 96,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined),
      );
    } else if (widget.media.isImage) {
      final url = _url;
      preview = GestureDetector(
        onTap: url == null ? null : _openImage,
        child: Container(
          width: 120,
          height: 96,
          color: Colors.grey.shade200,
          child: url == null
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Image.network(
                  url,
                  width: 120,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                  ),
                ),
        ),
      );
    } else {
      preview = GestureDetector(
        onTap: _url == null ? null : _openVideo,
        child: Container(
          width: 120,
          height: 96,
          color: Colors.black87,
          child: Center(
            child: _url == null
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 36),
                      SizedBox(height: 2),
                      Icon(Icons.videocam, color: Colors.white54, size: 14),
                    ],
                  ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                preview,
                if (widget.onDelete != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _delete(),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.media.isImage ? 'Imagen' : 'Video',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final callback = widget.onDelete;
    if (callback != null) callback();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.detail});

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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final StatusHistory entry;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 14, color: color),
      title: Text(statusLabel(entry.status)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.note != null && entry.note!.isNotEmpty)
            Text(entry.note!, textAlign: TextAlign.left),
          Text(
            _fmt(entry.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'en_revision':
      return const Color(0xFF1565C0);
    case 'en_proceso':
      return const Color(0xFFEF6C00);
    case 'resuelta':
      return const Color(0xFF2E7D32);
    case 'rechazada':
      return const Color(0xFFC62828);
    case 'archivada':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'en_revision':
      return Icons.manage_search;
    case 'en_proceso':
      return Icons.build_circle_outlined;
    case 'resuelta':
      return Icons.check_circle_outline;
    case 'rechazada':
      return Icons.cancel_outlined;
    case 'archivada':
      return Icons.archive_outlined;
    default:
      return Icons.assignment_late_outlined;
  }
}