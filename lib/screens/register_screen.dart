import 'package:flutter/material.dart';
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
      _showMessage('Correo verificado, bienvenido');
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _awaitingVerification
                ? _buildVerification(theme)
                : _buildForm(theme),
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
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
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
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) => (v == null || v.length < 6)
                ? 'Mínimo 6 caracteres'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) =>
                (v != _password.text) ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrarme'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerification(ThemeData theme) {
    return Form(
      key: _otpKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          const Text(
            'Verificación',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enviamos un código a ${_email.text.trim()}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otp,
            decoration: const InputDecoration(
              labelText: 'Código de verificación',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: (v) =>
                (v == null || v.length < 4) ? 'Ingresa el código' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _verifyOtp,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verificar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _resendCode,
            child: const Text('Reenviar código'),
          ),
        ],
      ),
    );
  }
}