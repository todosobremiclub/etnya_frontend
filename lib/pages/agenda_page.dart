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

  DateTime _weekStart = _mondayOf(DateTime.now());

  // cache por mes: "YYYY-MM" -> lista completa de clases del mes
  final Map<String, List<Map<String, dynamic>>> _cachePorMes = {};
  // clases de la semana, agrupadas por día (YYYY-MM-DD)
  Map<String, List<Map<String, dynamic>>> _clasesPorDia = {};
  // feriados (YYYY-MM-DD)
  final Set<String> _feriados = {};

  static DateTime _mondayOf(DateTime d) {
    final wd = d.weekday; // 1=Mon..7=Sun
    return DateTime(d.year, d.month, d.day - (wd - 1));
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final perfil = await Api.getPerfil();
      final nombre = (perfil['nombre'] ?? '').toString().trim();

      // feriados desde backend
      final feriadosRaw = await Api.getFeriados();
      for (final f in feriadosRaw) {
        final fechaStr = (f['fecha'] ?? '').toString();
        if (fechaStr.isEmpty) continue;
        final ymd = fechaStr.length >= 10 ? fechaStr.substring(0, 10) : fechaStr;
        _feriados.add(ymd);
      }

      await _loadWeekClasses();

      if (!mounted) return;
      setState(() {
        _nombre = nombre;
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

  Future<void> _loadWeekClasses() async {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    // meses involucrados en la semana
    final meses = {
      _ym(days.first),
      _ym(days.last),
    };

    // cargar clases por mes usando el endpoint mensual existente
    for (final ym in meses) {
      if (!_cachePorMes.containsKey(ym)) {
        final data = await Api.getClases(ym);
        final items = ((data['items'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _cachePorMes[ym] = items;
      }
    }

    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final d in days) {
      byDay[_ymd(d)] = [];
    }

    // filtrar clases de la semana y descartar las que caen en feriado
    for (final ym in meses) {
      final items = _cachePorMes[ym] ?? [];
      for (final c in items) {
        DateTime? dt =
            DateTime.tryParse((c['fecha_hora'] ?? '').toString());
        if (dt == null) {
          final f = DateTime.tryParse((c['fecha'] ?? '').toString());
          final horaStr = (c['hora'] ?? '').toString();
          if (f != null && horaStr.isNotEmpty) {
            final parts = horaStr.split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            dt = DateTime(f.year, f.month, f.day, h, m);
          } else {
            dt = f;
          }
        }
        if (dt == null) continue;

        final dayOnly = DateTime(dt.year, dt.month, dt.day);
        if (dayOnly.isBefore(_weekStart) ||
            dayOnly.isAfter(_weekStart.add(const Duration(days: 6)))) {
          continue; // fuera de la semana
        }

        final ymd = _ymd(dayOnly);

        // si es feriado, NO se muestra
        if (_feriados.contains(ymd)) continue;

        byDay[ymd]?.add(c);
      }
    }

    // ordenar clases por fecha/hora dentro del día
    byDay.forEach((k, v) {
      v.sort((a, b) {
        DateTime? da =
            DateTime.tryParse((a['fecha_hora'] ?? '').toString());
        DateTime? db =
            DateTime.tryParse((b['fecha_hora'] ?? '').toString());
        return (da ?? DateTime(2000))
            .compareTo(db ?? DateTime(2000));
      });
    });

    if (!mounted) return;
    setState(() {
      _clasesPorDia = byDay;
    });
  }

  void _changeWeek(int delta) async {
    setState(() {
      _loading = true;
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
    await _loadWeekClasses();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _weekLabel() {
    final start = _weekStart;
    final end = _weekStart.add(const Duration(days: 6));
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${meses[start.month - 1]} ${start.year}';
    }
    return '${start.day}/${start.month} – ${end.day}/${end.month} ${end.year}';
  }

  String _weekdayNameShort(DateTime d) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[d.weekday - 1];
  }

  String _weekdayNameLong(DateTime d) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final todayKey = _ymd(DateTime.now());

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

            // Navegación de semana
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _weekLabel(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Panel tipo calendario (cajas de día)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFA3D8C3),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: GridView.builder(
                  itemCount: days.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 columnas
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3 / 4,
                  ),
                  itemBuilder: (context, index) {
                    final d = days[index];
                    final ymd = _ymd(d);
                    final clases = _clasesPorDia[ymd] ?? [];
                    final isToday = ymd == todayKey;

                    return _DayBox(
                      date: d,
                      clases: clases,
                      isToday: isToday,
                      weekdayShort: _weekdayNameShort(d),
                      weekdayLong: _weekdayNameLong(d),
                    );
                  },
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

/// Caja de un día en el calendario semanal
class _DayBox extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> clases;
  final bool isToday;
  final String weekdayShort;
  final String weekdayLong;

  const _DayBox({
    required this.date,
    required this.clases,
    required this.isToday,
    required this.weekdayShort,
    required this.weekdayLong,
  });

  @override
  Widget build(BuildContext context) {
    final fechaLabel = '${date.day}/${date.month}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9EFEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? const Color(0xFF4A148C) : Colors.black26,
          width: isToday ? 2 : 0.5,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFF4A148C).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del día
          Row(
            children: [
              Text(
                weekdayShort,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isToday ? const Color(0xFF4A148C) : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                fechaLabel,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: isToday ? const Color(0xFF4A148C) : Colors.black54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          if (clases.isEmpty)
            const Text(
              'Sin clases',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 12,
                color: Colors.black54,
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: clases.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, i) {
                  final c = clases[i];
                  final horaStr = (c['hora'] ?? '').toString();
                  final sede = (c['sede'] ?? '').toString();
                  final tipo = (c['tipo'] ?? '').toString();
                  final estado = (c['estado'] ?? '').toString();

                  final hhmm =
                      horaStr.length >= 5 ? horaStr.substring(0, 5) : horaStr;
                  final tipoTxt =
                      tipo.isNotEmpty ? tipo : 'Clase normal';

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hhmm,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          sede,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          tipoTxt +
                              (estado.isNotEmpty ? ' · $estado' : ''),
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}