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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _StatusMessage(
        icon: Icons.cloud_off,
        title: 'No se pudieron cargar las denuncias',
        detail: _error!,
        retryLabel: 'Reintentar',
        onRetry: _load,
      );
    }
    if (_complaints.isEmpty) {
      return const _StatusMessage(
        icon: Icons.inbox_outlined,
        title: 'Aún no tienes denuncias',
        detail: 'Toca "Nueva" para reportar un problema en tu ciudad.',
      );
    }
    final filtered = _complaints.where((c) {
      if (_filter == 'En proceso') return c.status == 'en_proceso' || c.status == 'en_revision';
      if (_filter == 'Resueltas') return c.status == 'resuelta';
      if (_filter == 'Rechazadas') return c.status == 'rechazada';
      return true;
    }).toList();
    return Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), child: Row(children: ['Todas', 'En proceso', 'Resueltas', 'Rechazadas'].map((name) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(name), selected: _filter == name, onSelected: (_) => setState(() => _filter = name)))).toList())),
      Expanded(child: RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    )),
    ]);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 66,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.report_problem_outlined,
                        color: DenuPeColors.primary, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(complaint.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Código: #${complaint.id.length > 8 ? complaint.id.substring(0, 8) : complaint.id}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        _StatusChip(status: complaint.status),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: DenuPeColors.text),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                categoryName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      authorityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
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