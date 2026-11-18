import 'package:flutter/material.dart';
// import 'package:media_kit/media_kit.dart'; // Comentado temporariamente para teste
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MediaKit.ensureInitialized(); // Comentado temporariamente para teste

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