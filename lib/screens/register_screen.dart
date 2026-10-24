import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/denupe_colors.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import '../services/app_scope.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = false;
  bool _awaitingVerification = false;
  bool _verified = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _accepted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await api.signUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      );
      if (!mounted) return;
      if (result.requireEmailVerification) {
        setState(() => _awaitingVerification = true);
        _showMessage(
          'Revisa tu correo: te enviamos un código de verificación.',
        );
      } else {
        _showMessage('Cuenta creada');
        Navigator.of(context).pop();
      }
    } on InsforgeException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Error de conexión');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await api.verifyEmail(email: _email.text.trim(), otp: _otp.text.trim());
      // verifyEmail crea la sesión (onAuthStateChange ya emitió signedIn),
      // pero RegisterScreen sigue pusheada encima de AuthGate: hay que
      // regresar a la raíz para que el menú principal quede visible.
      if (!mounted) return;
      setState(() => _verified = true);
    } on InsforgeException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Error de conexión');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _loading = true);
    try {
      await api.sendVerificationEmail(_email.text.trim());
      _showMessage('Código reenviado');
    } on InsforgeException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DenuPe', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: DenuPeColors.primary, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: _verified ? _buildSuccess() : _awaitingVerification
                ? _buildVerification(theme) : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intro(Icons.person_add_alt_1_rounded, 'Crea tu cuenta', 'Regístrate para comenzar a reportar problemas en tu ciudad.'),
          const SizedBox(height: 28),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre completo', hintText: 'Tu nombre y apellidos',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico', hintText: 'tu@email.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Ingresa un correo válido'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            decoration: const InputDecoration(
              labelText: 'Contraseña', hintText: 'Mínimo 8 caracteres', suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _showPassword = !_showPassword)),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: !_showPassword,
            validator: (v) => (v == null || v.length < 8)
                ? 'Mínimo 8 caracteres'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña', hintText: 'Repite tu contraseña', suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _showConfirm = !_showConfirm)),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: !_showConfirm,
            validator: (v) =>
                (v != _password.text) ? 'Las contraseñas no coinciden' : null,
          ),
          CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, activeColor: DenuPeColors.primary, value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false), title: const Text('Acepto los términos de uso y la política de privacidad', style: TextStyle(fontSize: 13))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_loading || !_accepted) ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrarse'),
          ),
        ],
      ),
    );
  }

  Widget _intro(IconData icon, String title, String subtitle, {Color color = DenuPeColors.primary}) => Column(children: [
    CircleAvatar(radius: 44, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 44)),
    const SizedBox(height: 18),
    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: DenuPeColors.text)),
    const SizedBox(height: 10),
    Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5)),
  ]);
  Widget _buildVerification(ThemeData theme) => Form(key: _otpKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _intro(Icons.mark_email_unread_outlined, 'Verifica tu correo', 'Hemos enviado un código de verificación a ' + _email.text.trim()),
    const SizedBox(height: 24),
    const Text('Ingresa el código de 6 dígitos para completar tu registro.', textAlign: TextAlign.center),
    const SizedBox(height: 24),
    TextFormField(controller: _otp, autofocus: true, textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: '••••••', counterText: '', border: OutlineInputBorder()), validator: (v) => v == null || v.length != 6 ? 'Ingresa los 6 dígitos' : null),
    const SizedBox(height: 18),
    const Text('¿No recibiste el código?', textAlign: TextAlign.center),
    TextButton(onPressed: _loading ? null : _resendCode, child: const Text('Reenviar código')),
    const SizedBox(height: 24),
    FilledButton(onPressed: _loading ? null : _verifyOtp, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verificar')),
  ]));
  Widget _buildSuccess() => Column(children: [
    const SizedBox(height: 65),
    _intro(Icons.check_circle_rounded, '¡Cuenta verificada!', 'Tu cuenta ha sido creada correctamente. Ahora puedes comenzar a usar DenuPe para reportar problemas en tu ciudad.', color: DenuPeColors.success),
    const SizedBox(height: 110),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Continuar →'))),
    const SizedBox(height: 25),
  ]);
}