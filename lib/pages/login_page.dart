import 'package:flutter/material.dart';
import '../api/api.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogged;
  const LoginPage({super.key, required this.onLogged});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
    final colorScheme = Theme.of(context).colorScheme;

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
                    color: colorScheme.primary,
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
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Número de socio',
                  prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primary.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apeCtrl,
                decoration: InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primary.withOpacity(0.06),
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
                    activeColor: colorScheme.primary,
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
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
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
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Ingresar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_add_alt_1, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          children: [
                            const TextSpan(text: '¿Todavía no sos socia?\n'),
                            TextSpan(
                              text: 'Registrate',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
