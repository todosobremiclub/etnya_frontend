import 'package:flutter/material.dart';

/// Formulario único de aceptación de las "Pautas Etnya Pilates". Se muestra una sola vez al
/// hacer login, y la aceptación vence al año (el backend controla el
/// vencimiento en `terminos_aceptados`, ver GET /app/perfil). La única
/// acción disponible para continuar usando la app es aceptar; quien no
/// acepta solo puede cerrar sesión.
/// Desde el panel (columna T&C) se puede "reiniciar" la aceptación para
/// que se le vuelva a mostrar a la socia.
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
              'Pautas Etnya Pilates',
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
                'Para usar la app de Etnya Pilates necesitás leer y aceptar '
                'estas pautas. La aceptación es válida por un año; pasado ese '
                'plazo te las vamos a volver a pedir.',
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
                  'PAUTAS ETNYA PILATES\n\n'
                  '•  Para recuperar una clase, es necesario avisar la '
                  'inasistencia con un mínimo de 2 horas de anticipación.\n\n'
                  '•  La cantidad de recuperaciones disponibles por mes '
                  'dependerá de la frecuencia semanal del plan.\n\n'
                  '•  Las recuperaciones estarán sujetas a disponibilidad de '
                  'días, horarios y cupos.\n\n'
                  '•  Si no se asiste a una recuperación previamente '
                  'coordinada, la clase se pierde.\n\n'
                  '•  En caso de ausentarse durante un período prolongado y '
                  'querer conservar el horario habitual, será necesario '
                  'mantener el abono al día y coordinar las recuperaciones '
                  'correspondientes.\n\n'
                  '•  El abono mensual deberá realizarse del 1 al 10 de cada '
                  'mes, independientemente de la cantidad de clases a las que '
                  'se asista durante ese período.\n\n'
                  '•  Cada alumno/a deberá informar cualquier condición de '
                  'salud, lesión, embarazo, cirugía o situación que pueda '
                  'afectar la práctica y comunicar cualquier cambio en su '
                  'estado de salud.\n\n'
                  '•  La práctica de Pilates se realiza bajo responsabilidad de '
                  'cada alumno/a respecto de su propio estado de salud, '
                  'comprometiéndose a respetar sus posibilidades y a informar '
                  'ante cualquier dolor, molestia o malestar durante la '
                  'clase.\n\n'
                  '•  El uso de los equipos y materiales deberá realizarse '
                  'siguiendo las indicaciones de las instructoras, cuidando el '
                  'espacio y los elementos de Etnya.\n\n'
                  'Estas pautas tienen como objetivo organizar el '
                  'funcionamiento de Etnya Pilates y garantizar una '
                  'experiencia segura, respetuosa y agradable para todos.',
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
                'Leí y acepto las Pautas Etnya Pilates',
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
