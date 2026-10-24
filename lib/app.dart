import 'package:flutter/material.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import 'theme/denupe_colors.dart';
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
        useMaterial3: true,
        scaffoldBackgroundColor: DenuPeColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DenuPeColors.primary,
          primary: DenuPeColors.primary,
          onPrimary: DenuPeColors.surface,
          surface: DenuPeColors.surface,
          onSurface: DenuPeColors.text,
          error: DenuPeColors.error,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DenuPeColors.primary,
          foregroundColor: DenuPeColors.surface,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: DenuPeColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: DenuPeColors.border),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: DenuPeColors.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DenuPeColors.primary,
            foregroundColor: DenuPeColors.surface,
            minimumSize: const Size(0, 48),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: DenuPeColors.surface,
          indicatorColor: DenuPeColors.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: DenuPeColors.text),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: DenuPeColors.text,
          contentTextStyle: TextStyle(color: DenuPeColors.surface),
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