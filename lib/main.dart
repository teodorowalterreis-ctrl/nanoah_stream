import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/login_screen.dart';

void main() async {
  // 1. Garante que o motor do Flutter está ligado
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa o MediaKit obrigatoriamente antes de qualquer runApp ou uso de vídeo
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
        brightness: Brightness.dark, 
      ),
      home: const LoginScreen(),
    );
  }
}