import 'package:flutter/material.dart';
import '../api/api.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogged;
  const LoginPage({super.key, required this.onLogged});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Verdes del logo de Etnya (solo para el login; el resto de la app
  // mantiene su paleta).
  static const Color _verdeAgua = Color(0xFF00A69B); // verde agua del círculo del logo

  final _nroCtrl = TextEditingController();
  final _apeCtrl = TextEditingController();
  bool _loading = false;
  bool _recordarme = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await Api.login(numero: _nroCtrl.text.trim(), apellido: _apeCtrl.text.trim());
      widget.onLogged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Image.asset('assets/logo.jpeg', height: 140),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'PILATES',
                  style: TextStyle(
                    color: _verdeAgua,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '¡Bienvenida/o!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Iniciá sesión para continuar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nroCtrl,
                cursorColor: _verdeAgua,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Número de socio',
                  prefixIcon: Icon(Icons.badge_outlined, color: _verdeAgua),
                  floatingLabelStyle: const TextStyle(color: _verdeAgua),
                  filled: true,
                  fillColor: _verdeAgua.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apeCtrl,
                cursorColor: _verdeAgua,
                decoration: InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline, color: _verdeAgua),
                  floatingLabelStyle: const TextStyle(color: _verdeAgua),
                  filled: true,
                  fillColor: _verdeAgua.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _recordarme,
                    activeColor: _verdeAgua,
                    onChanged: (v) => setState(() => _recordarme = v ?? false),
                  ),
                  const Text('Recordarme'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // Verde agua suave, como el fondo de los campos.
                    backgroundColor: _verdeAgua.withOpacity(0.15),
                    foregroundColor: _verdeAgua,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _verdeAgua,
                          ),
                        )
                      : const Text(
                          'Ingresar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
