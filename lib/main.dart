import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:insforge_flutter/insforge_flutter.dart';

import 'app.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Se dibuja de inmediato un marco de carga y la inicialización (red y
  // almacenamiento seguro) ocurre después, para que cualquier fallo se vea
  // como un mensaje en pantalla y nunca como una pantalla negra.
  runApp(const DenuPeBootstrap());
}

class DenuPeBootstrap extends StatefulWidget {
  const DenuPeBootstrap({super.key});

  @override
  State<DenuPeBootstrap> createState() => _DenuPeBootstrapState();
}

class _DenuPeBootstrapState extends State<DenuPeBootstrap> {
  late final Future<void> _init = _bootstrap();

  Future<void> _bootstrap() async {
    await dotenv.load(fileName: '.env');
    try {
      await Insforge.initialize(url: Config.baseUrl, anonKey: Config.anonKey);
    } catch (_) {
      // Sesión persistida ilegible (Keystore corrupta tras reinstalar, respaldo
      // restaurado, etc.): se limpia el almacenamiento seguro y se reintenta.
      try {
        await const FlutterSecureStorage().deleteAll();
      } catch (_) {}
      await Insforge.initialize(url: Config.baseUrl, anonKey: Config.anonKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo iniciar la aplicación.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return const DenuPeApp();
      },
    );
  }
}
