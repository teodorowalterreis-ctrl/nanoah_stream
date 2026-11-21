import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegistering = false; // Alterna entre Login e Criar Conta

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _submitButtonFocus = FocusNode();
  final _toggleModeFocus = FocusNode();

  bool _isLoading = false;
  String _message = '';
  bool _isError = true;

  @override
  void initState() {
    super.initState();
    // Atualiza o visual quando qualquer campo ou botão ganha/perde foco no controle da TV
    for (final node in [
      _nameFocus,
      _usernameFocus,
      _passwordFocus,
      _submitButtonFocus,
      _toggleModeFocus,
    ]) {
      node.addListener(_onFocusChange);
    }

    // Coloca o foco inicial no primeiro campo assim que a tela abre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isRegistering) {
        _nameFocus.requestFocus();
      } else {
        _usernameFocus.requestFocus();
      }
    });
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final node in [
      _nameFocus,
      _usernameFocus,
      _passwordFocus,
      _submitButtonFocus,
      _toggleModeFocus,
    ]) {
      node.removeListener(_onFocusChange);
      node.dispose();
    }
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    if (_isRegistering) {
      // Processo de Registo
      final result = await ApiService.register(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isError = result['status'] != 'success';
        _message = result['message'];
      });

      if (!_isError) {
        // Se criou com sucesso, muda para a aba de login após 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _isRegistering = false;
            _message = 'Conta criada com sucesso! Faça login.';
          });
          _usernameFocus.requestFocus();
        });
      }
    } else {
      // Processo de Login
      final result = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['status'] == 'success') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _isError = true;
          _message = result['message'] ?? 'Erro desconhecido';
        });
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, FocusNode focusNode) {
    final bool hasFocus = focusNode.hasFocus;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: hasFocus ? Colors.lightBlueAccent : Colors.grey,
        fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
      ),
      filled: true,
      fillColor: hasFocus ? const Color(0xFF162032) : const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: hasFocus
            ? const BorderSide(color: Colors.amberAccent, width: 2.5)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.amberAccent, width: 2.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool submitFocused = _submitButtonFocus.hasFocus;
    final bool toggleFocused = _toggleModeFocus.hasFocus;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "NANOAH STREAM",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegistering
                      ? "Crie a sua nova conta"
                      : "Insira as suas credenciais para aceder",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                if (_message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _isError
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isError ? Colors.red : Colors.green,
                      ),
                    ),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _isError ? Colors.redAccent : Colors.greenAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Campo de Nome Completo (Apenas visível ao registar)
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_usernameFocus);
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Nome Completo', _nameFocus),
                  ),
                  const SizedBox(height: 16),
                ],

                // Campo Utilizador
                TextField(
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocus);
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Utilizador', _usernameFocus),
                ),
                const SizedBox(height: 16),

                // Campo Palavra-passe
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_submitButtonFocus);
                    _handleSubmit();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Palavra-passe', _passwordFocus),
                ),
                const SizedBox(height: 24),

                // Botão Principal (Entrar / Criar Conta)
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    focusNode: _submitButtonFocus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      side: submitFocused
                          ? const BorderSide(color: Colors.amberAccent, width: 3)
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isRegistering ? 'CRIAR CONTA' : 'ENTRAR',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botão Alternar Login / Registo
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: toggleFocused
                        ? Border.all(color: Colors.amberAccent, width: 2)
                        : null,
                  ),
                  child: TextButton(
                    focusNode: _toggleModeFocus,
                    onPressed: () {
                      final nextRegistering = !_isRegistering;
                      setState(() {
                        _isRegistering = nextRegistering;
                        _message = '';
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (nextRegistering) {
                          _nameFocus.requestFocus();
                        } else {
                          _usernameFocus.requestFocus();
                        }
                      });
                    },
                    child: Text(
                      _isRegistering
                          ? "Já tem uma conta? Faça Login"
                          : "Não tem conta? Registe-se aqui",
                      style: TextStyle(
                        color: toggleFocused
                            ? Colors.amberAccent
                            : Colors.blueAccent,
                        fontWeight:
                            toggleFocused ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}