import 'package:flutter/material.dart';

class TermsPage extends StatefulWidget {
  final Future<void> Function() onAccepted;
  final Future<void> Function() onRejected;

  const TermsPage({
    super.key,
    required this.onAccepted,
    required this.onRejected,
  });

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _checked = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_checked || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onAccepted();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onRejected();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y condiciones'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Para usar la app de Etnya Pilates necesitás aceptar los términos y condiciones de uso.',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  // TODO: reemplazar por texto legal real
                  'Acá va el texto completo de términos, condiciones y política de privacidad de Etnya Pilates.\n\n'
                  '• Uso de la app y responsabilidad del usuario.\n'
                  '• Tratamiento de datos personales.\n'
                  '• Comunicación vía notificaciones push, email y WhatsApp.\n'
                  '• Políticas de cancelación y asistencia a clases.\n'
                  '• Otras cláusulas que definan ustedes.\n\n'
                  'Al aceptar, confirmás que leíste y estás de acuerdo con estas condiciones.',
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            CheckboxListTile(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              title: const Text(
                'He leído y acepto los términos y condiciones',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _checked ? _accept : null,
                      child: Text(_saving ? 'Guardando…' : 'Aceptar y continuar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reject,
                      child: const Text('No acepto / Salir'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}