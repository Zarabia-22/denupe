import 'package:flutter/material.dart';

import '../models.dart';
import '../services/app_scope.dart';
import 'profile_edit_screen.dart';

/// Perfil del usuario autenticado: datos personales, rol y entidad.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<Authority> _autoridades = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([api.myProfile(), authorities()]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _autoridades = results[1] as List<Authority>;
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

  Future<void> _edit() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: profile),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final profile = _profile;
    if (profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No se pudo cargar el perfil',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final email = api.currentUser?.email;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(profile, email),
          const SizedBox(height: 20),
          if (profile.fullName != null && profile.fullName!.isNotEmpty)
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Nombre completo',
              value: profile.fullName!,
            ),
          if (email != null)
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'Correo electrónico',
              value: email,
            ),
          if (profile.dni != null && profile.dni!.isNotEmpty)
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'DNI',
              value: profile.dni!,
            ),
          if (profile.phone != null && profile.phone!.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: profile.phone!,
            ),
          if (profile.district != null && profile.district!.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Distrito',
              value: profile.district!,
            ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cuenta',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Rol',
                    value: _roleLabel(profile.role),
                  ),
                  if (profile.isFuncionario) ...[
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Entidad',
                      value: authorityNameOf(_autoridades, profile.autoridadId),
                    ),
                  ],
                  if (profile.createdAt != null) ...[
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: 'Miembro desde',
                      value: _formatDate(profile.createdAt!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Profile profile, String? email) {
    final theme = Theme.of(context);
    final initials = _initials(profile.fullName ?? email ?? '');
    final title = profile.fullName ?? email ?? 'Sin nombre';
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            initials,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        if (email != null && profile.fullName != null) ...[
          const SizedBox(height: 4),
          Text(email,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ],
    );
  }
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words.first.substring(0, 1) + words.last.substring(0, 1))
      .toUpperCase();
}

String _roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Administrador';
    case 'funcionario':
      return 'Funcionario municipal';
    case 'citizen':
      return 'Ciudadano';
    default:
      return role;
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}