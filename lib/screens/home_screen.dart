import 'package:flutter/material.dart';

import '../services/app_scope.dart';
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
  int _index = 0;
  int _notificationsTick = 0;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    final token = currentAccessToken();
    if (token != null) {
      realtime.connect(token: token);
    }
    notificationsTick.addListener(_onNotificationsTick);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await api.myProfile();
      if (!mounted) return;
      setState(() {
        _isStaff = profile.isFuncionario;
        if (!_isStaff && _index > 3) _index = 0;
      });
    } catch (_) {
      // Sin rol conocido: no se muestra el panel.
    }
  }

  void _onNotificationsTick() {
    if (!mounted) return;
    setState(() => _notificationsTick = notificationsTick.value);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo cerrar sesión')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DenuPe', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              _isStaff
                  ? ['Mis denuncias', 'Panel', 'Notificaciones', 'Perfil'][_index]
                  : ['Nueva denuncia', 'Mis denuncias', 'Notificaciones', 'Perfil'][_index],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          ),
        ],
      ),
      body: IndexedStack(
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
      bottomNavigationBar: NavigationBar(
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
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
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