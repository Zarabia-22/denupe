import 'package:flutter/material.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class DenuPeApp extends StatelessWidget {
  const DenuPeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DenuPe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Pantalla guardia: muestra login o el shell principal según la sesión.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    // La sesión ya fue restaurada por Insforge.initialize().
    _signedIn = Insforge.instance.auth.currentUser != null;
    Insforge.instance.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() {
        _signedIn = state.session?.user != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _signedIn ? const HomeScreen() : const LoginScreen();
  }
}