import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/denupe_colors.dart';

import '../models.dart';
import '../services/app_scope.dart';
import '../services/friendly_error.dart';
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _load(showSpinner: false, notifyHome: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(NotificacionesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick) {
      _load(showSpinner: false);
    }
  }

  Future<void> _load({bool showSpinner = true, bool notifyHome = false}) async {
    if (!mounted) return;
    if (showSpinner) setState(() => _loading = true);
    try {
      final items = await api.notifications();
      if (!mounted) return;
      final unreadBefore = _items.where((n) => !n.isRead).length;
      final unreadAfter = items.where((n) => !n.isRead).length;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
      if (notifyHome && unreadAfter != unreadBefore) bumpNotificationsTick();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
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
      if (!mounted) return;
    }
    if (!notification.isRead) {
      try {
        await api.markNotificationRead(notification.id);
        if (!mounted) return;
        setState(() {
          _items = _items
              .map((n) => n.id == notification.id
                  ? AppNotification(
                      id: n.id,
                      userId: n.userId,
                      complaintId: n.complaintId,
                      title: n.title,
                      body: n.body,
                      isRead: true,
                      createdAt: n.createdAt,
                    )
                  : n)
              .toList();
        });
        bumpNotificationsTick();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _markAllRead() async {
    final unreadBefore = _items.where((n) => !n.isRead).toList();
    if (unreadBefore.isEmpty) return;
    try {
      await api.markAllNotificationsRead();
      final after = await api.notifications();
      if (!mounted) return;
      final unreadAfter = after.where((n) => !n.isRead).length;
      setState(() {
        _items = after;
        _error = null;
      });
      if (unreadAfter < unreadBefore.length) {
        bumpNotificationsTick();
      }
      if (unreadAfter > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unreadAfter == 1
                  ? 'No se pudo marcar 1 notificación como leída.'
                  : 'No se pudieron marcar $unreadAfter notificaciones como leídas.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar las notificaciones', textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
          ],
          ),
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
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 56),
                      SizedBox(height: 12),
                      Text(
                        'No hay alertas. Te avisaremos aquí cuando tu denuncia cambie de estado.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final group in ['Hoy', 'Esta semana', 'Más antiguas']) ...[
                        if (_items.any((n) => _notificationGroup(n.createdAt) == group)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                            child: Text(group, style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DenuPeColors.text,
                            )),
                          ),
                          for (final item in _items.where(
                              (n) => _notificationGroup(n.createdAt) == group)) ...[
                            _NotificationCard(
                              notification: item,
                              onTap: () => _open(item),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ],
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
        : progress ? DenuPeColors.warning : DenuPeColors.primary;
    final unread = !notification.isRead;
    final background = unread
        ? (rejected ? const Color(0xFFFCE8E6)
            : resolved ? const Color(0xFFE7F4E9)
            : progress ? const Color(0xFFFFF4D6) : const Color(0xFFE3F2FD))
        : DenuPeColors.surface;
    final icon = rejected ? Icons.cancel_outlined
        : resolved ? Icons.check_circle_outline
        : progress ? Icons.pending_outlined : Icons.notifications_active_outlined;
    final titleStyle = TextStyle(
      fontWeight: unread ? FontWeight.bold : FontWeight.w500,
      color: unread ? DenuPeColors.text : Colors.grey.shade700,
    );
    final bodyStyle = TextStyle(
      color: unread ? DenuPeColors.text : Colors.grey.shade600,
    );
    return Card(
      color: background,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: unread ? color.withValues(alpha: 0.35) : DenuPeColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: unread ? color : Colors.grey.shade300,
                child: Icon(
                  icon,
                  color: unread
                      ? (progress && !rejected && !resolved ? DenuPeColors.text : Colors.white)
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: titleStyle),
                  if (notification.body != null && notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notification.body!, style: bodyStyle),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _fmt(notification.createdAt),
                    style: TextStyle(fontSize: 12, color: unread ? color : Colors.grey.shade500),
                  ),
                ],
              )),
              Icon(Icons.chevron_right, color: unread ? DenuPeColors.text : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _notificationGroup(DateTime created) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(created.year, created.month, created.day);
  if (!day.isBefore(today)) return 'Hoy';
  if (today.difference(day).inDays < 7) return 'Esta semana';
  return 'Más antiguas';
}
