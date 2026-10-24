import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';

import '../models.dart';
import '../services/app_scope.dart';
import 'complaint_detail_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.tick = 0});

  /// Contador global que se incrementa cuando cambian las notificaciones.
  final int tick;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotificacionesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick) {
      _load(showSpinner: false);
    }
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final items = await api.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open(AppNotification notification) async {
    final complaintId = notification.complaintId;
    if (complaintId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(complaintId: complaintId),
        ),
      );
    }
    if (!notification.isRead) {
      try {
        await api.markNotificationRead(notification.id);
        bumpNotificationsTick();
      } catch (_) {}
    }
  }

  Future<void> _markAllRead() async {
    try {
      await api.markAllNotificationsRead();
      bumpNotificationsTick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
            const Text('No se pudieron cargar las notificaciones'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final hasUnread = _items.any((n) => !n.isRead);
    return Column(
      children: [
        if (_items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: TextButton.icon(
                onPressed: hasUnread ? _markAllRead : null,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Marcar todas como leídas'),
              ),
            ),
          ),
        Expanded(
          child: _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 56),
                      SizedBox(height: 12),
                      Text(
                          'No hay alertas. Te avisaremos aquí cuando tu denuncia cambie de estado.'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _NotificationCard(
                        notification: item,
                        onTap: () => _open(item),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = '${notification.title} ${notification.body ?? ''}'.toLowerCase();
    final rejected = text.contains('rechaz') || text.contains('error');
    final resolved = text.contains('resuelt') || text.contains('atendid');
    final progress = text.contains('proceso') || text.contains('revisi');
    final color = rejected ? DenuPeColors.error
        : resolved ? DenuPeColors.success
        : progress ? DenuPeColors.warningText : DenuPeColors.primary;
    final background = rejected ? const Color(0xFFFCE8E6)
        : resolved ? const Color(0xFFE7F4E9)
        : progress ? const Color(0xFFFFF4D6) : const Color(0xFFE3F2FD);
    final icon = rejected ? Icons.cancel_outlined
        : resolved ? Icons.check_circle_outline
        : progress ? Icons.pending_outlined : Icons.notifications_active_outlined;
    return Card(
      color: background,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold, color: DenuPeColors.text)),
                  if (notification.body != null && notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notification.body!, style: const TextStyle(color: DenuPeColors.text)),
                  ],
                  const SizedBox(height: 6),
                  Text(_fmt(notification.createdAt), style: TextStyle(fontSize: 12, color: color)),
                ],
              )),
              const Icon(Icons.chevron_right, color: DenuPeColors.text),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';