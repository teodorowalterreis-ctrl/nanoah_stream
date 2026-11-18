import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/login_screen.dart';

void main() async {
  // Garante que o motor do Flutter está pronto
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o MediaKit de forma segura
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint("Erro ao inicializar MediaKit: $e");
  }

  // CAPTURA DE ERROS: Se algo falhar no arranque, mostra no ecrã em vez de ficar preto
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red[900],
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  'ERRO NO ARRANQUE:\n\n${details.exception}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  runApp(const NanoahStreamApp());
}

class NanoahStreamApp extends StatelessWidget {
  const NanoahStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nanoah Stream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark, 
      ),
      home: const LoginScreen(),
    );
  }
}