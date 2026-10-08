import 'package:flutter/material.dart';

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
      ]);
      if (!mounted) return;
      setState(() {
        _complaint = results[0] as Complaint?;
        _history = results[1] as List<StatusHistory>;
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
          const Divider(height: 32),
          _InfoRow(label: 'Categoría', detail: _categoryLabel(complaint.categoryId)),
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