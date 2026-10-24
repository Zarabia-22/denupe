import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';

import '../models.dart';
import '../services/app_scope.dart';
import 'complaint_detail_screen.dart';

class MisDenunciasScreen extends StatefulWidget {
  const MisDenunciasScreen({super.key});

  @override
  State<MisDenunciasScreen> createState() => _MisDenunciasScreenState();
}

class _MisDenunciasScreenState extends State<MisDenunciasScreen> {
  List<Complaint> _complaints = [];
  List<Category> _cats = [];
  List<Authority> _autoridades = [];
  final Set<String> _subscribed = {};
  bool _loading = true;
  String _filter = 'Todas';
  String? _error;

  @override
  void initState() {
    super.initState();
    notificationsTick.addListener(_onTick);
    _load();
  }

  @override
  void dispose() {
    notificationsTick.removeListener(_onTick);
    for (final id in _subscribed) {
      realtime.unsubscribeComplaint(id);
    }
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    _load();
  }

  void _subscribeTo(List<Complaint> complaints) {
    for (final c in complaints) {
      if (_subscribed.add(c.id)) {
        realtime.subscribeComplaint(c.id, (event) {
          if (!mounted) return;
          _load();
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.myComplaints(),
        categories(),
        authorities(),
      ]);
      if (!mounted) return;
      setState(() {
        _complaints = results[0] as List<Complaint>;
        _cats = results[1] as List<Category>;
        _autoridades = results[2] as List<Authority>;
        _loading = false;
      });
      _subscribeTo(_complaints);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openDetail(Complaint complaint) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComplaintDetailScreen(complaintId: complaint.id),
      ),
    );
    _load();
  }

  bool _matchesFilter(Complaint complaint) {
    switch (_filter) {
      case 'En proceso':
        return complaint.status == 'en_proceso' ||
            complaint.status == 'en_revision';
      case 'Resueltas':
        return complaint.status == 'resuelta';
      case 'Rechazadas':
        return complaint.status == 'rechazada';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _complaints.where(_matchesFilter).toList();
    const filters = ['Todas', 'En proceso', 'Resueltas', 'Rechazadas'];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: filters.map((name) {
              final selected = _filter == name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(name),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFFE3F2FD),
                  labelStyle: TextStyle(
                    color: selected ? DenuPeColors.primary : DenuPeColors.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected ? DenuPeColors.primary : DenuPeColors.border,
                  ),
                  onSelected: (_) => setState(() => _filter = name),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _StatusMessage(
                      icon: Icons.cloud_off,
                      title: 'No se pudieron cargar las denuncias',
                      detail: _error!,
                      retryLabel: 'Reintentar',
                      onRetry: _load,
                    )
                  : _complaints.isEmpty
                      ? const _StatusMessage(
                          icon: Icons.inbox_outlined,
                          title: 'Aún no tienes denuncias',
                          detail: 'Toca "Nueva" para reportar un problema en tu ciudad.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: filtered.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 90),
                                    _StatusMessage(
                                      icon: Icons.filter_alt_off_outlined,
                                      title: 'Sin denuncias en este estado',
                                      detail: 'No tienes denuncias que coincidan con el filtro "$_filter".',
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return _ComplaintCard(
                                      complaint: item,
                                      categoryName: categoryNameOf(_cats, item.categoryId),
                                      authorityName: authorityNameOf(_autoridades, item.autoridadId),
                                      onTap: () => _openDetail(item),
                                    );
                                  },
                                ),
                        ),
        ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.complaint,
    required this.categoryName,
    required this.authorityName,
    required this.onTap,
  });

  final Complaint complaint;
  final String categoryName;
  final String authorityName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = complaint.createdAt;
    final dateText = '${date.day} ${_monthName(date.month)} ${date.year}';
    return Card(
      margin: EdgeInsets.zero,
      color: DenuPeColors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: DenuPeColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComplaintThumbnail(complaintId: complaint.id),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DenuPeColors.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Código: #${complaint.id.length > 8 ? complaint.id.substring(0, 8) : complaint.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ),
                        const SizedBox(width: 4),
                        _StatusChip(status: complaint.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              const Padding(
                padding: EdgeInsets.only(top: 25),
                child: Icon(Icons.chevron_right, size: 19, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return months[month - 1];
}

/// Obtiene la primera evidencia real, si existe, del almacenamiento privado.
class _ComplaintThumbnail extends StatefulWidget {
  const _ComplaintThumbnail({required this.complaintId});
  final String complaintId;

  @override
  State<_ComplaintThumbnail> createState() => _ComplaintThumbnailState();
}

class _ComplaintThumbnailState extends State<_ComplaintThumbnail> {
  late Future<String?> _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ComplaintThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaintId != widget.complaintId) {
      _imageUrl = _loadImage();
    }
  }

  Future<String?> _loadImage() async {
    try {
      final media = await api.complaintMedia(widget.complaintId);
      for (final item in media) {
        if (item.isImage) {
          return await api.complaintMediaSignedUrl(item.storageKey);
        }
      }
    } catch (_) {
      // La falta de una miniatura no debe impedir ver la denuncia.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 76,
        height: 80,
        child: FutureBuilder<String?>(
          future: _imageUrl,
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (url == null) return _placeholder();
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFE3F2FD),
    child: const Icon(Icons.image_outlined,
        color: DenuPeColors.primary, size: 30),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final isInProgress = status == 'en_proceso';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isInProgress
            ? DenuPeColors.warning
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),

      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: isInProgress ? DenuPeColors.text : color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'en_revision':
      return DenuPeColors.primary;
    case 'en_proceso':
      return DenuPeColors.warningText;
    case 'resuelta':
      return DenuPeColors.success;
    case 'rechazada':
      return DenuPeColors.error;
    case 'archivada':
      return Colors.grey;
    default: // recibida
      return DenuPeColors.primary;
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    this.detail,
    this.retryLabel,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (detail != null) ...[
              const SizedBox(height: 10),
              Text(detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.45)),
            ],
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel!),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }
}