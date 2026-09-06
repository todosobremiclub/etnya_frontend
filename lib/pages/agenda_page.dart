import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  bool _loading = true;
  String _nombre = '';
  // Modalidad de la socia (ej. "Pilates Reformer"), igual que en el Home:
  // si viene con aclaraciones después de un "-" (ej. "Pilates Reformer -
  // 2 x semana"), se muestra solo la parte antes del guion.
  String _tipoClase = '';

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // cache por mes: "YYYY-MM" -> clases del mes ya con "_fecha" (DateTime) resuelta
  final Map<String, List<Map<String, dynamic>>> _cachePorMes = {};
  // feriados (YYYY-MM-DD)
  final Set<String> _feriados = {};

  List<Map<String, dynamic>> _clasesDelMes = [];

  String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final perfil = await Api.getPerfil();
      final nombre = (perfil['nombre'] ?? '').toString().trim();
      final tipoClaseRaw = (perfil['tipo_clase'] ?? '').toString().trim();
      final tipoClase = tipoClaseRaw.split('-').first.trim();

      // feriados desde backend
      final feriadosRaw = await Api.getFeriados();
      for (final f in feriadosRaw) {
        final fechaStr = (f['fecha'] ?? '').toString();
        if (fechaStr.isEmpty) continue;
        final ymd = fechaStr.length >= 10 ? fechaStr.substring(0, 10) : fechaStr;
        _feriados.add(ymd);
      }

      await _loadMonthClasses();

      if (!mounted) return;
      setState(() {
        _nombre = nombre;
        _tipoClase = tipoClase;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando agenda: $e')),
      );
    }
  }

  Future<void> _loadMonthClasses() async {
    final ym = _ym(_mes);

    if (!_cachePorMes.containsKey(ym)) {
      final data = await Api.getClases(ym);
      final items = ((data['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _cachePorMes[ym] = items;
    }

    final items = _cachePorMes[ym] ?? [];
    final procesadas = <Map<String, dynamic>>[];

    for (final c in items) {
      DateTime? dt = DateTime.tryParse((c['fecha_hora'] ?? '').toString());
      if (dt == null) {
        final f = DateTime.tryParse((c['fecha'] ?? '').toString());
        final horaStr = (c['hora'] ?? '').toString();
        if (f != null && horaStr.isNotEmpty) {
          final partes = horaStr.split(':');
          final h = int.tryParse(partes[0]) ?? 0;
          final m = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
          dt = DateTime(f.year, f.month, f.day, h, m);
        } else {
          dt = f;
        }
      }
      if (dt == null) continue;

      final dayOnly = DateTime(dt.year, dt.month, dt.day);
      final ymd =
          '${dayOnly.year}-${dayOnly.month.toString().padLeft(2, '0')}-${dayOnly.day.toString().padLeft(2, '0')}';
      if (_feriados.contains(ymd)) continue; // el centro no abre ese día

      procesadas.add({...c, '_fecha': dt});
    }

    procesadas.sort(
      (a, b) => (a['_fecha'] as DateTime).compareTo(b['_fecha'] as DateTime),
    );

    if (!mounted) return;
    setState(() {
      _clasesDelMes = procesadas;
    });
  }

  void _changeMonth(int delta) async {
    setState(() {
      _loading = true;
      _mes = DateTime(_mes.year, _mes.month + delta, 1);
    });
    await _loadMonthClasses();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _mesLabel() {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${meses[_mes.month - 1]} ${_mes.year}';
  }

  String _weekdayShort(DateTime d) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[d.weekday - 1];
  }

  Future<void> _avisarNoAsistencia(Map<String, dynamic> clase) async {
    final id = clase['id'];
    if (id == null) return;

    final comentarioController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No voy a asistir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Confirmás que NO vas a asistir a la clase?'),
            const SizedBox(height: 12),
            TextField(
              controller: comentarioController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Agregá un comentario (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, avisar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final comentario = comentarioController.text.trim();
      await Api.avisarNoAsistencia(
        id as int,
        comentario: comentario.isEmpty ? null : comentario,
      );
      if (!mounted) return;
      setState(() {
        clase['estado'] = 'con_aviso';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listo, avisamos que no vas a asistir.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el aviso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final now = DateTime.now();
    final futuras = _clasesDelMes
        .where((c) => (c['_fecha'] as DateTime).isAfter(now))
        .toList(); // ya vienen ordenadas de más próxima a más lejana
    final anteriores = _clasesDelMes
        .where((c) => !(c['_fecha'] as DateTime).isAfter(now))
        .toList()
        .reversed
        .toList(); // más reciente primero

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    "Hola $_nombre!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'https://etnya.onrender.com/admin-panel/logo.jpeg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 8),

            // Navegación de mes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _NavMesButton(
                    icon: Icons.chevron_left,
                    onTap: () => _changeMonth(-1),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 15, color: Color(0xFF0E3A5D)),
                        const SizedBox(width: 6),
                        Text(
                          _mesLabel(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Georgia',
                            color: Color(0xFF0E3A5D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NavMesButton(
                    icon: Icons.chevron_right,
                    onTap: () => _changeMonth(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Clases del mes: un panel verde para "Próximas clases" y,
            // debajo, un panel lila para "Clases anteriores" (cada uno solo
            // tan alto como su contenido, como en el diseño de referencia).
            Expanded(
              child: (futuras.isEmpty && anteriores.isEmpty)
                  ? const Center(
                      child: Text(
                        'No tenés clases este mes',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (futuras.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA9DDC4),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _SectionLabel(
                                    text: 'Próximas clases',
                                    icon: Icons.event_note,
                                    color: Color(0xFF3E9C6B),
                                  ),
                                  const SizedBox(height: 12),
                                  // Carrete horizontal con TODAS las clases
                                  // próximas del mes (no solo la siguiente).
                                  SizedBox(
                                    height: 150,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: futuras.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, i) {
                                        final c = futuras[i];
                                        return SizedBox(
                                          width: 112,
                                          child: _ClaseCell(
                                            clase: c,
                                            weekdayShort: _weekdayShort(
                                                c['_fecha'] as DateTime),
                                            esFutura: true,
                                            tipoClase: _tipoClase,
                                            onAvisar: () =>
                                                _avisarNoAsistencia(c),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (futuras.isNotEmpty && anteriores.isNotEmpty)
                            const SizedBox(height: 14),
                          if (anteriores.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE7F6),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 14,
                                    runSpacing: 6,
                                    children: const [
                                      _SectionLabel(
                                        text: 'Clases anteriores',
                                        icon: Icons.bar_chart,
                                        color: Color(0xFF9D84D0),
                                      ),
                                      _LeyendaEstados(),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: anteriores.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 0.68,
                                    ),
                                    itemBuilder: (context, i) {
                                      final c = anteriores[i];
                                      return _ClaseCell(
                                        clase: c,
                                        weekdayShort: _weekdayShort(
                                            c['_fecha'] as DateTime),
                                        esFutura: false,
                                        tipoClase: _tipoClase,
                                        onAvisar: null,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
            ),

            const SocialFooter(),
          ],
        ),
      ),
    );
  }
}

/// Círculo con flecha para ir al mes anterior/siguiente.
class _NavMesButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavMesButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFFE5D4F9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF7A5AA4)),
      ),
    );
  }
}

/// Título de sección con un ícono en un círculo de color, para separar
/// "Próximas clases" de "Clases anteriores" dentro del mismo listado.
class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
            color: Color(0xFF0E3A5D),
          ),
        ),
      ],
    );
  }
}

/// Referencia de colores/íconos de "Anteriores" (mismos que usa _ClaseCell).
class _LeyendaEstados extends StatelessWidget {
  const _LeyendaEstados();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(Icons.check_circle, const Color(0xFF4FBF75), 'Asistí'),
        item(Icons.info, const Color(0xFFE0A83B), 'Justificada'),
        item(Icons.cancel, const Color(0xFFD9534F), 'No asistí'),
      ],
    );
  }
}

/// Celda compacta de una clase (pasada o futura) para la grilla de 4 por fila.
class _ClaseCell extends StatelessWidget {
  final Map<String, dynamic> clase;
  final String weekdayShort;
  final bool esFutura;
  final String tipoClase;
  final VoidCallback? onAvisar;

  const _ClaseCell({
    required this.clase,
    required this.weekdayShort,
    required this.esFutura,
    required this.tipoClase,
    required this.onAvisar,
  });

  ({String label, Color color, IconData icon})? _estadoInfo(String estado) {
    switch (estado) {
      case 'asistio':
        return (
          label: 'Asistió',
          color: const Color(0xFF4FBF75),
          icon: Icons.check_circle,
        );
      case 'con_aviso':
        return (
          label: 'Avisó',
          color: const Color(0xFFE0A83B),
          icon: Icons.info,
        );
      case 'sin_aviso':
        return (
          label: 'Sin aviso',
          color: const Color(0xFFD9534F),
          icon: Icons.cancel,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = clase['_fecha'] as DateTime;
    final estado = (clase['estado'] ?? '').toString();
    final info = _estadoInfo(estado);
    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    // En clases futuras sin estado registrado todavía, mostramos el botón
    // "No voy" solo hasta 1 hora antes de la clase; pasado ese límite (o si
    // ya empezó), se deja de mostrar (el backend además lo vuelve a
    // validar por si el pedido llegara igual).
    final faltaMasDeUnaHora = dt.difference(DateTime.now()).inMinutes >= 60;
    final mostrarBotonAviso =
        esFutura && info == null && onAvisar != null && faltaMasDeUnaHora;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge lila con el día de la semana, como en el diseño.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE5D4F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              weekdayShort,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: Color(0xFF7A5AA4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${dt.day}/${dt.month}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF0E3A5D),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 11, color: Colors.black45),
              const SizedBox(width: 3),
              Text(
                '$hhmm hs',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          if (tipoClase.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              tipoClase,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w500,
                fontSize: 9,
                color: Color(0xFF8B6FC9),
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (info != null)
            Icon(info.icon, size: 16, color: info.color)
          else if (mostrarBotonAviso)
            InkWell(
              onTap: onAvisar,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'No voy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.black38,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.black26,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
