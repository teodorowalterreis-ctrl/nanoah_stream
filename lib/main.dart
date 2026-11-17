import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart'; // Importante para o motor de vídeo
import 'screens/login_screen.dart';

void main() {
  // 1. Garante que os bindings do Flutter estão prontos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. INICIALIZAÇÃO OBRIGATÓRIA DO MEDIA_KIT (Faltava este passo!)
  MediaKit.ensureInitialized();

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
        // Deixa o tema geral escuro por padrão combinando com o app
        brightness: Brightness.dark, 
      ),
      home: const LoginScreen(),
    );
  }
}