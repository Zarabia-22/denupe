import 'package:flutter/material.dart';

import '../models.dart';
import '../services/app_scope.dart';
import 'complaint_detail_screen.dart';

/// Panel de trabajo del funcionario municipal: denuncias asignadas a su entidad.
class PanelMunicipalScreen extends StatefulWidget {
  const PanelMunicipalScreen({super.key});

  @override
  State<PanelMunicipalScreen> createState() => _PanelMunicipalScreenState();
}

class _PanelMunicipalScreenState extends State<PanelMunicipalScreen> {
  List<Complaint> _complaints = [];
  List<Category> _cats = [];
  List<Authority> _autoridades = [];
  final Set<String> _subscribed = {};
  String _entidad = '';
  bool _loading = true;
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
        api.authorityComplaints(),
        categories(),
        authorities(),
        api.myProfile(),
      ]);
      final profile = results[3] as Profile;
      if (!mounted) return;
      setState(() {
        _complaints = results[0] as List<Complaint>;
        _cats = results[1] as List<Category>;
        _autoridades = results[2] as List<Authority>;
        _entidad = authorityNameOf(_autoridades, profile.autoridadId);
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
        builder: (_) => ComplaintDetailScreen(
          complaintId: complaint.id,
          showStatusUpdate: true,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _StatusMessage(
        icon: Icons.cloud_off,
        title: 'No se pudo cargar el panel',
        detail: _error!,
        retryLabel: 'Reintentar',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.account_balance,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Denuncias de $_entidad',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_complaints.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _StatusMessage(
                icon: Icons.inbox_outlined,
                title: 'No hay denuncias asignadas',
                detail: 'Cuando un ciudadano reporte un problema de tu entidad, aparecerá aquí.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList.separated(
                itemCount: _complaints.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _complaints[index];
                  return _PanelComplaintCard(
                    complaint: item,
                    categoryName: categoryNameOf(_cats, item.categoryId),
                    onTap: () => _openDetail(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelComplaintCard extends StatelessWidget {
  const _PanelComplaintCard({
    required this.complaint,
    required this.categoryName,
    required this.onTap,
  });

  final Complaint complaint;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = complaint.createdAt;
    final dateText = '${date.day}/${date.month}/${date.year}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      complaint.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusChip(status: complaint.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                categoryName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                complaint.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    dateText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (complaint.address != null &&
                      complaint.address!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.place_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        complaint.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
    default: // recibida
      return Colors.blueGrey;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
    );
  }
}