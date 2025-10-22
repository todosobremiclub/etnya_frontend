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
  final _dniCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await Api.login(numero: _nroCtrl.text.trim(), dni: _dniCtrl.text.trim());
      widget.onLogged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ingreso', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(controller: _nroCtrl, decoration: const InputDecoration(labelText: 'Número de socio')),
              const SizedBox(height: 12),
              TextField(controller: _dniCtrl, decoration: const InputDecoration(labelText: 'DNI'), obscureText: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Ingresando…' : 'Ingresar'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
