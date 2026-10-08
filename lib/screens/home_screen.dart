import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import 'mis_denuncias_screen.dart';
import 'new_complaint_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _notificationsTick = 0;

  @override
  void initState() {
    super.initState();
    final token = currentAccessToken();
    if (token != null) {
      realtime.connect(token: token);
    }
    notificationsTick.addListener(_onNotificationsTick);
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
        title: const Text('DenuPe'),
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
          const MisDenunciasScreen(),
          NuevaDenunciaScreen(onCreated: () => setState(() => _index = 0)),
          NotificacionesScreen(tick: _notificationsTick),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Mis denuncias',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Nueva',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }
}