import 'package:flutter/material.dart';

/// Formulario único de aceptación de términos, condiciones y riesgos
/// médicos asociados a la práctica de Pilates. Se muestra una sola vez al
/// hacer login, y la aceptación vence al año (el backend controla el
/// vencimiento en `terminos_aceptados`, ver GET /app/perfil). La única
/// acción disponible para continuar usando la app es aceptar; quien no
/// acepta solo puede cerrar sesión.
///
/// TODO: el texto de riesgos médicos es de PRUEBA. Reemplazar por el texto
/// legal definitivo (revisado por quien corresponda) antes de publicar.
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Image.asset('assets/logo.jpeg', height: 72),
            const SizedBox(height: 10),
            Text(
              'Términos, condiciones y riesgos médicos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Para usar la app de Etnya Pilates necesitás aceptar este '
                'formulario. La aceptación es válida por un año; pasado ese '
                'plazo te lo vamos a volver a pedir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.primary.withOpacity(0.2)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: const Text(
                  // TODO: texto de prueba, reemplazar por el texto legal real.
                  'TÉRMINOS Y CONDICIONES\n\n'
                  '• Uso de la app y responsabilidad del usuario.\n'
                  '• Tratamiento de datos personales.\n'
                  '• Comunicación vía notificaciones push, email y WhatsApp.\n'
                  '• Políticas de cancelación y asistencia a clases.\n'
                  '• Otras cláusulas que definan ustedes.\n\n'
                  'RIESGOS MÉDICOS ASOCIADOS A LA PRÁCTICA DE PILATES\n\n'
                  '1. Declaro que mi estado de salud actual me permite realizar '
                  'actividad física de intensidad moderada, y que no tengo '
                  'ninguna condición médica que lo desaconseje.\n\n'
                  '2. Declaro que voy a informar a mi profesor/a, antes de cada '
                  'clase, cualquier lesión, dolor, embarazo, cirugía reciente u '
                  'otra condición que pueda ser relevante para adaptar los '
                  'ejercicios.\n\n'
                  '3. Entiendo que, como toda actividad física, el Pilates '
                  'conlleva un riesgo de lesión (muscular, articular u otro), y '
                  'que Etnya y su personal no se hacen responsables por '
                  'lesiones derivadas de omitir información médica relevante o '
                  'de no seguir las indicaciones del profesor/a.\n\n'
                  '4. Me comprometo a consultar con un profesional de la salud '
                  'antes de iniciar esta actividad si tengo dudas sobre mi '
                  'aptitud física para realizarla.\n\n'
                  '5. Autorizo a que, ante una emergencia durante la clase, el '
                  'personal de Etnya pueda solicitar asistencia médica en mi '
                  'nombre.\n\n'
                  'Al aceptar, confirmo que leí y estoy de acuerdo con estas '
                  'condiciones, y que la información que voy a brindar sobre mi '
                  'salud es correcta.',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ),
            CheckboxListTile(
              value: _checked,
              activeColor: colorScheme.primary,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _checked = v ?? false),
              title: const Text(
                'He leído y acepto los términos, condiciones y los riesgos '
                'médicos asociados a la práctica de Pilates',
                style: TextStyle(fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colorScheme.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: (_checked && !_saving) ? _accept : null,
                  child: Text(
                    _saving ? 'Guardando…' : 'Aceptar y continuar',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _reject,
              child: const Text(
                'No acepto / Cerrar sesión',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
