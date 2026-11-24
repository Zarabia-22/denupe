import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                        Flexible(child: TextButton(onPressed: _showRecoveryDialog, child: const Text('¿Olvidaste tu contraseña?', textAlign: TextAlign.end, style: TextStyle(fontSize: 12)))),
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

  void _showRecoveryDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordRecoveryDialog(initialEmail: _email.text.trim()),
    );
  }
}

class _PasswordRecoveryDialog extends StatefulWidget {
  const _PasswordRecoveryDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<_PasswordRecoveryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  String _token = '';

  static const _titles = [
    'Recuperar contraseña',
    'Verifica tu correo',
    'Nueva contraseña',
    'Contraseña actualizada',
  ];

  final _emailValidator = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) =>
      error is InsforgeException ? error.message : 'Error de conexión. Intenta nuevamente.';

  Future<void> _sendCode({bool stayOnStep = false}) async {
    if (!stayOnStep && !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.requestPasswordReset(email: _email.text.trim());
      if (!mounted) return;
      setState(() {
        if (!stayOnStep) _step = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() => _sendCode(stayOnStep: true);

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _token = await api.exchangePasswordResetCode(
        email: _email.text.trim(),
        code: _code.text.trim(),
      );
      if (!mounted) return;
      setState(() => _step = 2);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.resetPassword(
        token: _token,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _step = 3);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildContent(ThemeData theme) {
    if (_step == 3) {
      return const Text(
        'Tu contraseña se actualizó correctamente. Inicia sesión con la nueva contraseña.',
        style: TextStyle(height: 1.45),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == 0)
          const Text(
            'Ingresa tu correo. Guardaremos la solicitud y te enviaremos un código de 6 dígitos.',
            style: TextStyle(height: 1.45),
          ),
        if (_step == 1)
          Text(
            'Ingresa el código enviado a ${_email.text.trim()}.',
            style: const TextStyle(height: 1.45),
          ),
        if (_step == 2)
          const Text(
            'El código es válido. Elige una nueva contraseña de al menos 6 caracteres.',
            style: TextStyle(height: 1.45),
          ),
        const SizedBox(height: 20),
        if (_step == 0)
          TextFormField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'tu@email.com',
              prefixIcon: Icon(Icons.mail_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || !_emailValidator.hasMatch(v.trim())
                ? 'Ingresa un correo electrónico válido'
                : null,
          ),
        if (_step == 1)
          TextFormField(
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, letterSpacing: 10),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.length != 6
                ? 'Ingresa los 6 dígitos'
                : null,
          ),
        if (_step == 2) ...[
          TextFormField(
            controller: _password,
            autofocus: true,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
            validator: (v) => v == null || v.length < 6
                ? 'Mínimo 6 caracteres'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPassword,
            obscureText: !_showPassword,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v != _password.text
                ? 'Las contraseñas no coinciden'
                : null,
          ),
        ],
        if (_step == 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loading ? null : _resendCode,
              child: const Text('Reenviar código'),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildAction({
    required String label,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    return TextButton(
      onPressed: _loading ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_titles[_step]),
      content: SizedBox(
        width: 360,
        child: Form(key: _formKey, child: _buildContent(theme)),
      ),
      actions: [
        if (_step == 0) ...[
          _buildAction(label: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
          _buildAction(label: 'Enviar código', onPressed: _sendCode, busy: _loading),
        ],
        if (_step == 1) ...[
          _buildAction(label: 'Volver', onPressed: () => setState(() => _step = 0)),
          _buildAction(label: 'Verificar', onPressed: _verifyCode, busy: _loading),
        ],
        if (_step == 2) ...[
          _buildAction(label: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
          _buildAction(label: 'Cambiar contraseña', onPressed: _changePassword, busy: _loading),
        ],
        if (_step == 3)
          _buildAction(label: 'Cerrar', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}