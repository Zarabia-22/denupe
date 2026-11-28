import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/friendly_error.dart';
import '../services/pending_evidence_store.dart';
import '../theme/denupe_colors.dart';
import 'mis_denuncias_screen.dart';
import 'new_complaint_screen.dart';
import 'notifications_screen.dart';
import 'panel_municipal_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 1;
  int _notificationsTick = 0;
  int _unreadNotifications = 0;
  bool _isStaff = false;
  bool _profileError = false;
  final PendingEvidenceStore _evidenceStore = PendingEvidenceStore();
  List<PendingEvidenceBatch> _pendingEvidence = [];
  bool _loadingPendingEvidence = false;
  bool _retryingPendingEvidence = false;

  @override
  void initState() {
    super.initState();
    realtime.connect();
    notificationsTick.addListener(_onNotificationsTick);
    _loadProfile();
    _refreshUnreadNotifications();
    _loadPendingEvidence();
  }

  Future<void> _loadProfile() async {
    if (_profileError && mounted) setState(() => _profileError = false);
    try {
      final profile = await api.myProfile();
      if (!mounted) return;
      setState(() {
        _isStaff = profile.isFuncionario;
        if (!_isStaff && _index > 3) _index = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }

  Future<void> _loadPendingEvidence() async {
    final userId = api.currentUser?.id;
    if (userId == null) return;
    if (mounted) setState(() => _loadingPendingEvidence = true);
    try {
      final batches = await _evidenceStore.pendingForUser(userId);
      if (!mounted) return;
      setState(() => _pendingEvidence = batches);
    } catch (_) {
      // La pantalla principal debe seguir disponible aunque el almacenamiento local falle.
    } finally {
      if (mounted) setState(() => _loadingPendingEvidence = false);
    }
  }

  Future<void> _retryPendingEvidence() async {
    final userId = api.currentUser?.id;
    if (userId == null || _retryingPendingEvidence) return;
    setState(() => _retryingPendingEvidence = true);
    var uploaded = 0;
    var failed = 0;
    try {
      final batches = await _evidenceStore.pendingForUser(userId);
      for (final batch in batches) {
        for (var index = 0; index < batch.attachments.length; index++) {
          final item = batch.attachments[index];
          try {
            await api.uploadComplaintMedia(
              complaintId: batch.complaintId,
              bytes: item.bytes,
              filename: item.name,
              contentType: item.contentType,
              mediaType: item.mediaType,
            );
            await _evidenceStore.markUploaded(
              userId: userId,
              complaintId: batch.complaintId,
              fileKey: batch.keys[index],
            );
            uploaded++;
          } catch (_) {
            failed++;
          }
        }
      }
      await _loadPendingEvidence();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failed == 0
            ? 'Se recuperaron $uploaded evidencia(s) pendiente(s).'
            : 'Se recuperaron $uploaded evidencia(s); quedan $failed por reintentar.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron recuperar las evidencias: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _retryingPendingEvidence = false);
    }
  }

  void _onNotificationsTick() {
    if (!mounted) return;
    setState(() => _notificationsTick = notificationsTick.value);
    _refreshUnreadNotifications();
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final count = await api.unreadNotificationsCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    notificationsTick.removeListener(_onNotificationsTick);
    realtime.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.signOut();
      // AuthGate regresa a login vía onAuthStateChange.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesión cerrada en este dispositivo. ${friendlyError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DenuPe', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pendingEvidence.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              color: const Color(0xFFFFF8E1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: Color(0xFFF9A825)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_pendingEvidence.fold<int>(0, (sum, batch) => sum + batch.attachments.length)} evidencia(s) esperan conexión para terminar de cargarse.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _retryingPendingEvidence ? null : _retryPendingEvidence,
                      child: _retryingPendingEvidence
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),

          if (_profileError)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('No se pudo cargar tu perfil.')),
                  TextButton(
                    onPressed: _loadProfile,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                if (!_isStaff)
                  NuevaDenunciaScreen(onCreated: () => setState(() => _index = 1)),
                const MisDenunciasScreen(),
                if (_isStaff) const PanelMunicipalScreen(),
                NotificacionesScreen(tick: _notificationsTick),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: DenuPeColors.surface,
        indicatorColor: const Color(0xFFE3F2FD),
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          if (!_isStaff)
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Nueva',
            ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Mis denuncias',
          ),
          if (_isStaff)
            const NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Panel',
            ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(_unreadNotifications > 99 ? '99+' : '$_unreadNotifications'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(_unreadNotifications > 99 ? '99+' : '$_unreadNotifications'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notificaciones',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}