import 'package:flutter/material.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import '../services/app_scope.dart';
import '../theme/denupe_colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _remember = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await api.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      // El AuthGate detecta el inicio de sesión vía onAuthStateChange.
    } on InsforgeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error de conexión')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DenuPeColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Container(
                  width: double.infinity, height: 230,
                  padding: const EdgeInsets.fromLTRB(28, 34, 24, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [DenuPeColors.primaryDark, DenuPeColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Stack(children: [
                    const Align(alignment: Alignment.bottomRight, child: Icon(Icons.location_city_rounded, size: 170, color: Color(0x554CA5ED))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Image.asset(
                        'assets/denupe_logo.png',
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      const Text('DenuPe', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 6),
                      const Text('Tu voz construye\nuna ciudad mejor', style: TextStyle(fontSize: 18, height: 1.35, color: Colors.white)),
                    ]),
                  ]),
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(26, 34, 26, 32),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28), bottom: Radius.circular(24))),
                    child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Inicia sesión', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: DenuPeColors.text)),
                      const SizedBox(height: 8),
                      const Text('Accede a tu cuenta para gestionar tus denuncias.', style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF475569))),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
                        decoration: InputDecoration(labelText: 'Correo electrónico', hintText: 'tu@email.com', prefixIcon: const Icon(Icons.mail_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Ingresa un correo electrónico válido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password, obscureText: !_showPassword,
                        decoration: InputDecoration(labelText: 'Contraseña', hintText: 'Ingresa tu contraseña', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        )),
                        validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Checkbox(value: _remember, activeColor: DenuPeColors.primary, onChanged: (v) => setState(() => _remember = v ?? true)),
                        const Text('Recordarme', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        Flexible(child: TextButton(onPressed: _showRecoveryInfo, child: const Text('¿Olvidaste tu contraseña?', textAlign: TextAlign.end, style: TextStyle(fontSize: 12)))),
                      ]),
                      const SizedBox(height: 22),
                      SizedBox(height: 54, child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Iniciar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), SizedBox(width: 10), Icon(Icons.arrow_forward)]),
                      )),
                      const SizedBox(height: 30),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('¿No tienes una cuenta?', style: TextStyle(fontSize: 13)),
                        TextButton(onPressed: _loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Crear cuenta')),
                      ]),
                    ])),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showRecoveryInfo() {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: const Text('La recuperación por correo aún no está habilitada en esta versión. Contacta al equipo de soporte para recuperar el acceso.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
    ));
  }
}