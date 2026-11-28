import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/friendly_error.dart';
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

  @override
  void initState() {
    super.initState();
    realtime.connect();
    notificationsTick.addListener(_onNotificationsTick);
    _loadProfile();
    _refreshUnreadNotifications();
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