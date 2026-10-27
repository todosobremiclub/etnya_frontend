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

  // La próxima clase real (desde "ahora"), independiente del mes que se
  // esté navegando en la pantalla. Así, aunque la socia esté mirando un
  // mes ya terminado (o cualquier otro mes), siempre puede ver cuál es
  // su próxima clase.
  Map<String, dynamic>? _proximaClaseGlobal;

  // "Clases anteriores": se muestran las primeras 5 y el resto con "Ver más".
  bool _verMasAnteriores = false;
  static const int _anterioresVisibles = 5;

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
      await _cargarProximaClaseGlobal();

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
      // El backend manda la hora "de pared" de Buenos Aires marcada como
      // UTC; la pasamos a hora local para que las comparaciones contra
      // "ahora" (próximas/anteriores, límite de 24 hs del "No voy") den bien.
      if (dt.isUtc) {
        dt = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
      }

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

  /// Trae (usando el mismo caché por mes) todas las clases procesadas
  /// —con fecha resuelta y feriados descartados— de un mes puntual,
  /// sin tocar `_clasesDelMes` (que es la que se muestra según el mes
  /// que la socia está navegando).
  Future<List<Map<String, dynamic>>> _procesarMes(DateTime mes) async {
    final ym = _ym(mes);

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
      // El backend manda la hora "de pared" de Buenos Aires marcada como
      // UTC; la pasamos a hora local para que las comparaciones contra
      // "ahora" (próximas/anteriores, límite de 24 hs del "No voy") den bien.
      if (dt.isUtc) {
        dt = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
      }

      final dayOnly = DateTime(dt.year, dt.month, dt.day);
      final ymd =
          '${dayOnly.year}-${dayOnly.month.toString().padLeft(2, '0')}-${dayOnly.day.toString().padLeft(2, '0')}';
      if (_feriados.contains(ymd)) continue;

      procesadas.add({...c, '_fecha': dt});
    }

    procesadas.sort(
      (a, b) => (a['_fecha'] as DateTime).compareTo(b['_fecha'] as DateTime),
    );
    return procesadas;
  }

  /// Busca la próxima clase real a partir de "ahora", sin importar qué mes
  /// esté navegando la socia en la pantalla: primero mira el mes en curso
  /// y, si ahí ya no quedan clases futuras, sigue con el mes siguiente.
  Future<void> _cargarProximaClaseGlobal() async {
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month, 1);

    var candidatas = await _procesarMes(mesActual);
    var futuras = candidatas
        .where((c) => (c['_fecha'] as DateTime).isAfter(ahora))
        .toList();

    if (futuras.isEmpty) {
      final mesSiguiente = DateTime(mesActual.year, mesActual.month + 1, 1);
      candidatas = await _procesarMes(mesSiguiente);
      futuras = candidatas
          .where((c) => (c['_fecha'] as DateTime).isAfter(ahora))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _proximaClaseGlobal = futuras.isNotEmpty ? futuras.first : null;
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
        // Marcamos la clase como avisada en todas las copias que tenemos
        // (lista del mes, próxima clase y caché), así se ve igual en toda
        // la pantalla sin tener que recargar.
        clase['estado'] = 'con_aviso';
        for (final c in _clasesDelMes) {
          if (c['id'] == id) c['estado'] = 'con_aviso';
        }
        if (_proximaClaseGlobal?['id'] == id) {
          _proximaClaseGlobal!['estado'] = 'con_aviso';
        }
        for (final lista in _cachePorMes.values) {
          for (final c in lista) {
            if (c['id'] == id) c['estado'] = 'con_aviso';
          }
        }
      });
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.event_repeat, color: _kVerde, size: 36),
          title: const Text('¡Gracias por avisar!'),
          content: const Text(
            'Registramos que no vas a asistir. Nos vamos a estar comunicando '
            'con vos para coordinar la clase reprogramada.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
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
    final proxima = _proximaClaseGlobal;
    // Otras clases futuras del mes que se está mirando (sin repetir la
    // próxima clase, que ya va destacada arriba).
    final futuras = _clasesDelMes
        .where((c) => (c['_fecha'] as DateTime).isAfter(now))
        .where((c) => proxima == null || c['id'] != proxima['id'])
        .toList(); // ya vienen ordenadas de más próxima a más lejana
    final anteriores = _clasesDelMes
        .where((c) => !(c['_fecha'] as DateTime).isAfter(now))
        .toList()
        .reversed
        .toList(); // más reciente primero
    final anterioresAMostrar = _verMasAnteriores
        ? anteriores
        : anteriores.take(_anterioresVisibles).toList();

    // Asistencia del mes: clases a las que asistió sobre las que ya tienen
    // un estado registrado (asistió / justificada / no asistió).
    final conEstado = anteriores
        .where((c) => ['asistio', 'con_aviso', 'sin_aviso']
            .contains((c['estado'] ?? '').toString()))
        .toList();
    final asistidas =
        conEstado.where((c) => c['estado'] == 'asistio').length;
    final int? porcentaje = conEstado.isEmpty
        ? null
        : ((asistidas / conEstado.length) * 100).round();

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
                  child: Image.asset(
                    'assets/logo.jpeg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  // ---------- PRÓXIMA CLASE (siempre la real, sin importar
                  // el mes que se esté navegando) ----------
                  if (proxima != null)
                    _ProximaClaseDestacada(
                      clase: proxima,
                      weekdayLargo:
                          _weekdayLargo(proxima['_fecha'] as DateTime),
                      tipoClase: _tipoClase,
                      onAvisar: () => _avisarNoAsistencia(proxima),
                    )
                  else
                    const _CajaSuave(
                      child: Text(
                        'No tenés próximas clases agendadas',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _kTexto,
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // ---------- Navegación de mes ----------
                  Row(
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
                                size: 15, color: _kTexto),
                            const SizedBox(width: 6),
                            Text(
                              _mesLabel(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Georgia',
                                color: _kTexto,
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

                  if (futuras.isEmpty && anteriores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No tenés clases este mes',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                  // ---------- Siguientes clases del mes ----------
                  if (futuras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionLabel(
                      text: 'Siguientes clases',
                      icon: Icons.event_note,
                      color: _kVerde,
                    ),
                    const SizedBox(height: 10),
                    for (final c in futuras)
                      _ClaseFila(
                        clase: c,
                        weekdayShort: _weekdayShort(c['_fecha'] as DateTime),
                        tipoClase: _tipoClase,
                        esFutura: true,
                        onAvisar: () => _avisarNoAsistencia(c),
                      ),
                  ],

                  // ---------- Clases anteriores ----------
                  if (anteriores.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionLabel(
                      text: 'Clases anteriores',
                      icon: Icons.bar_chart,
                      color: Color(0xFF9D84D0),
                    ),
                    const SizedBox(height: 10),
                    for (final c in anterioresAMostrar)
                      _ClaseFila(
                        clase: c,
                        weekdayShort: _weekdayShort(c['_fecha'] as DateTime),
                        tipoClase: _tipoClase,
                        esFutura: false,
                        onAvisar: null,
                      ),
                    if (anteriores.length > _anterioresVisibles)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(
                              () => _verMasAnteriores = !_verMasAnteriores),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _verMasAnteriores ? 'Ver menos' : 'Ver más',
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  color: _kLila,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _verMasAnteriores
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _kLila,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // ---------- Mi asistencia ----------
                  if (porcentaje != null) ...[
                    const SizedBox(height: 10),
                    _MiAsistencia(porcentaje: porcentaje),
                  ],

                  // ---------- Importante ----------
                  const SizedBox(height: 12),
                  const _CajaSuave(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _kVerde, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Importante',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _kTexto,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Si no podés asistir, avisá con al menos 24 hs '
                                'de anticipación con el botón "No voy" para '
                                'que podamos reprogramar tu clase.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SocialFooter(),
          ],
        ),
      ),
    );
  }

  String _weekdayLargo(DateTime d) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return names[d.weekday - 1];
  }
}

// ======================= ESTILO =======================

const _kTexto = Color(0xFF0E3A5D);   // texto principal de la pantalla
const _kVerde = Color(0xFF3E9C6B);   // verde de "Próxima clase"
const _kLila = Color(0xFF8B6FC9);    // lila de modalidad / acentos
const _kLilaSuave = Color(0xFFE5D4F9);
const _kFondoProxima = Color(0xFFE9F1EE); // gris verdoso de la tarjeta
const _kHorasLimiteAviso = 24;       // "No voy" disponible hasta 24 hs antes

String _hhmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Puede usarse "No voy" si la clase no tiene estado y faltan al menos
/// 24 hs (el backend vuelve a validarlo).
bool _puedeAvisar(Map<String, dynamic> clase) {
  final estado = (clase['estado'] ?? '').toString();
  if (estado.isNotEmpty) return false;
  final dt = clase['_fecha'] as DateTime;
  return dt.difference(DateTime.now()).inHours >= _kHorasLimiteAviso;
}

/// Caja de fondo suave con bordes redondeados (próxima clase, importante).
class _CajaSuave extends StatelessWidget {
  final Widget child;
  const _CajaSuave({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kFondoProxima,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

/// Fila "ícono + texto" con la sede de la clase.
class _SedeLinea extends StatelessWidget {
  final String sede;
  final double size;
  const _SedeLinea({required this.sede, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_outlined, size: size + 2, color: Colors.black45),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            'Sede $sede',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: size,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de estado (Confirmada / Reprogramando).
class _EstadoChip extends StatelessWidget {
  final String texto;
  final IconData icon;
  final Color color;
  const _EstadoChip({required this.texto, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón "No voy" (solo visible hasta 24 hs antes de la clase).
class _NoVoyBoton extends StatelessWidget {
  final VoidCallback onTap;
  const _NoVoyBoton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          'No voy',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta grande "Próxima clase" con la ilustración de la cama.
class _ProximaClaseDestacada extends StatelessWidget {
  final Map<String, dynamic> clase;
  final String weekdayLargo;
  final String tipoClase;
  final VoidCallback onAvisar;

  const _ProximaClaseDestacada({
    required this.clase,
    required this.weekdayLargo,
    required this.tipoClase,
    required this.onAvisar,
  });

  @override
  Widget build(BuildContext context) {
    final dt = clase['_fecha'] as DateTime;
    final sede = (clase['sede'] ?? '').toString().trim();
    final avisada = (clase['estado'] ?? '').toString() == 'con_aviso';

    return _CajaSuave(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            text: 'Próxima clase',
            icon: Icons.calendar_month,
            color: _kVerde,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kLilaSuave,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          weekdayLargo.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: Color(0xFF7A5AA4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dt.day}/${dt.month}',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                          color: _kTexto,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            '${_hhmm(dt)} hs',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (tipoClase.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tipoClase,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            color: _kLila,
                          ),
                        ),
                      ],
                      if (sede.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _SedeLinea(sede: sede, size: 12),
                      ],
                      const SizedBox(height: 10),
                      avisada
                          ? const _EstadoChip(
                              texto: 'Reprogramando',
                              icon: Icons.event_repeat,
                              color: Color(0xFFE0A83B),
                            )
                          : const _EstadoChip(
                              texto: 'Confirmada',
                              icon: Icons.check_circle_outline,
                              color: _kVerde,
                            ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: Colors.black12,
                ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Image.asset(
                      'assets/reformer.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (avisada) ...[
            const SizedBox(height: 10),
            const Text(
              'Avisaste que no vas a asistir. Estamos coordinando tu clase '
              'reprogramada.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ] else if (_puedeAvisar(clase)) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _NoVoyBoton(onTap: onAvisar),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de una clase (siguientes o anteriores), con el formato de lista.
class _ClaseFila extends StatelessWidget {
  final Map<String, dynamic> clase;
  final String weekdayShort;
  final String tipoClase;
  final bool esFutura;
  final VoidCallback? onAvisar;

  const _ClaseFila({
    required this.clase,
    required this.weekdayShort,
    required this.tipoClase,
    required this.esFutura,
    required this.onAvisar,
  });

  ({String label, Color color, IconData icon})? _estadoInfo(String estado) {
    switch (estado) {
      case 'asistio':
        return (
          label: 'Asistí',
          color: const Color(0xFF4FBF75),
          icon: Icons.check_circle,
        );
      case 'con_aviso':
        return esFutura
            ? (
                label: 'Reprogramando',
                color: const Color(0xFFE0A83B),
                icon: Icons.event_repeat,
              )
            : (
                label: 'Justificada',
                color: const Color(0xFFE0A83B),
                icon: Icons.info,
              );
      case 'sin_aviso':
        return (
          label: 'No asistí',
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
    final sede = (clase['sede'] ?? '').toString().trim();
    final info = _estadoInfo((clase['estado'] ?? '').toString());
    final mostrarNoVoy = esFutura && onAvisar != null && _puedeAvisar(clase);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Día + fecha
            SizedBox(
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kLilaSuave,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      weekdayShort.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        color: Color(0xFF7A5AA4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${dt.day}/${dt.month}',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _kTexto,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.black12,
            ),
            // Hora + modalidad + sede
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        '${_hhmm(dt)} hs',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (tipoClase.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tipoClase,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 13,
                        color: _kLila,
                      ),
                    ),
                  ],
                  if (sede.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _SedeLinea(sede: sede, size: 10),
                  ],
                ],
              ),
            ),
            // Estado / No voy
            if (info != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(info.icon, size: 26, color: info.color),
                  const SizedBox(width: 6),
                  Text(
                    info.label,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
            else if (mostrarNoVoy)
              _NoVoyBoton(onTap: onAvisar!),
          ],
        ),
      ),
    );
  }
}

/// Bloque "Mi asistencia" con el porcentaje del mes.
class _MiAsistencia extends StatelessWidget {
  final int porcentaje;
  const _MiAsistencia({required this.porcentaje});

  String get _mensaje {
    if (porcentaje >= 90) return '¡Excelente!';
    if (porcentaje >= 70) return '¡Muy bien!';
    return '¡Seguí así!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9FB),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_border_rounded,
                color: _kLila, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi asistencia del mes',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    color: _kTexto,
                  ),
                ),
                Text(
                  '$porcentaje%',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _kLila,
                  ),
                ),
                Text(
                  _mensaje,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 12,
                    color: _kVerde,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value: porcentaje / 100,
                    strokeWidth: 5,
                    valueColor: const AlwaysStoppedAnimation(_kLila),
                    backgroundColor: Colors.white,
                  ),
                ),
                Text(
                  '$porcentaje%',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTexto,
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// Título de sección con un ícono en un círculo de color.
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.4,
            color: color,
          ),
        ),
      ],
    );
  }
}
