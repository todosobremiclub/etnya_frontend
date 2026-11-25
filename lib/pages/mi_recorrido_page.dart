import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

// Paleta (los mismos colores que ya usa la app: violetas de Novedades /
// Notificaciones, verde agua del logo y fondo general).
const _kFondo = Color(0xFFF2F7F5);
const _kVioleta = Color(0xFF9D84D0);
const _kVioletaOscuro = Color(0xFF7A5AA4);
const _kLila = Color(0xFFE5D4F9);
const _kLilaSuave = Color(0xFFF3EDFC);
const _kVerdeAgua = Color(0xFF00A69B);
const _kVerdeAguaSuave = Color(0xFFD9EFEF);
const _kGrisAnillo = Color(0xFFE6E6E6);

const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// "Mi recorrido": progreso de la socia — clases del mes contra el
/// objetivo (clases programadas en el mes), constancia (% de asistencia),
/// récord (inicio, clases realizadas, mejor mes, racha) y ritmo semanal.
class MiRecorridoPage extends StatefulWidget {
  const MiRecorridoPage({super.key});

  @override
  State<MiRecorridoPage> createState() => _MiRecorridoPageState();
}

class _MiRecorridoPageState extends State<MiRecorridoPage> {
  bool _loading = true;
  String? _error;

  // Mes actual
  int _clasesMes = 0;
  int _objetivoMes = 0;

  // Constancia (asistidas / clases pasadas que tenía programadas)
  int? _asistenciaPct;

  // Récord
  DateTime? _inicio;
  int _clasesTotales = 0;
  String? _mejorMesLabel;
  int _rachaSemanas = 0;

  // Ritmo: últimas 5 semanas (la última es la actual), true = asistió
  List<bool> _ultimasSemanas = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  static String _ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime _lunes(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    return dia.subtract(Duration(days: dia.weekday - 1));
  }

  static DateTime? _fechaClase(Map<String, dynamic> c) {
    final iso = DateTime.tryParse((c['fecha_hora'] ?? '').toString());
    if (iso != null) return iso.toLocal();
    return DateTime.tryParse((c['fecha'] ?? '').toString());
  }

  Future<void> _cargar() async {
    try {
      final ahora = DateTime.now();

      // Perfil (fecha de inicio) y recorrido (clases totales históricas)
      final perfilF = Api.getPerfil().catchError((_) => <String, dynamic>{});
      final recorridoF =
          Api.getRecorrido().catchError((_) => <String, dynamic>{});
      final perfil = await perfilF;
      final recorrido = await recorridoF;

      _inicio = DateTime.tryParse((perfil['inicio_clases'] ?? '').toString())
          ?.toLocal();

      // Meses a consultar: desde el inicio (máx. 24 meses hacia atrás)
      // hasta el mes actual. Se piden en paralelo.
      final desdeMin = DateTime(ahora.year, ahora.month - 23, 1);
      var desde = _inicio != null
          ? DateTime(_inicio!.year, _inicio!.month, 1)
          : DateTime(ahora.year, ahora.month - 11, 1);
      if (desde.isBefore(desdeMin)) desde = desdeMin;

      final meses = <DateTime>[];
      for (var m = desde;
          !m.isAfter(DateTime(ahora.year, ahora.month, 1));
          m = DateTime(m.year, m.month + 1, 1)) {
        meses.add(m);
      }

      final respuestas = await Future.wait(meses.map((m) => Api.getClases(_ym(m))
          .catchError((_) => <String, dynamic>{})));

      final asistidasPorMes = <DateTime, int>{};
      final semanasConClase = <DateTime>{};
      int asistidas = 0;
      int pasadasProgramadas = 0;
      int clasesMes = 0;
      int objetivoMes = 0;

      for (var i = 0; i < meses.length; i++) {
        final mes = meses[i];
        final items = (respuestas[i]['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map));
        final esMesActual = mes.year == ahora.year && mes.month == ahora.month;

        for (final c in items) {
          final estado = (c['estado'] ?? '').toString().toLowerCase();
          if (estado.contains('cancel') || estado.contains('feriado')) continue;

          final fecha = _fechaClase(c);
          final asistio = estado == 'asistio';

          if (esMesActual) {
            objetivoMes++;
            if (asistio) clasesMes++;
          }

          if (asistio) {
            asistidasPorMes[mes] = (asistidasPorMes[mes] ?? 0) + 1;
            if (fecha != null) semanasConClase.add(_lunes(fecha));
          }

          // Para la constancia solo cuentan clases ya pasadas
          if (fecha != null && fecha.isBefore(ahora)) {
            if (asistio ||
                estado == 'con_aviso' ||
                estado == 'sin_aviso' ||
                estado.contains('ausente')) {
              pasadasProgramadas++;
              if (asistio) asistidas++;
            }
          }
        }
      }

      // Mejor mes
      String? mejorMes;
      if (asistidasPorMes.isNotEmpty) {
        final mejor = asistidasPorMes.entries
            .reduce((a, b) => b.value > a.value ? b : a);
        mejorMes = '${_meses[mejor.key.month - 1]} · ${mejor.value} clases';
      }

      // Racha: semanas seguidas con al menos una clase. Si la semana
      // actual todavía no tiene clase, no corta la racha (arranca a contar
      // desde la semana pasada).
      final semanaActual = _lunes(ahora);
      var cursor = semanasConClase.contains(semanaActual)
          ? semanaActual
          : semanaActual.subtract(const Duration(days: 7));
      int racha = 0;
      while (semanasConClase.contains(cursor)) {
        racha++;
        cursor = cursor.subtract(const Duration(days: 7));
      }

      final ultimas = List.generate(5, (i) {
        final s = semanaActual.subtract(Duration(days: 7 * (4 - i)));
        return semanasConClase.contains(s);
      });

      final totalesBackend = recorrido['clases_totales'];
      final totalCalculado =
          asistidasPorMes.values.fold<int>(0, (a, b) => a + b);

      if (!mounted) return;
      setState(() {
        _clasesMes = clasesMes;
        _objetivoMes = objetivoMes;
        _asistenciaPct = pasadasProgramadas == 0
            ? null
            : ((asistidas * 100) / pasadasProgramadas).round();
        _clasesTotales =
            totalesBackend is int ? totalesBackend : totalCalculado;
        _mejorMesLabel = mejorMes;
        _rachaSemanas = racha;
        _ultimasSemanas = ultimas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu recorrido: $e';
        _loading = false;
      });
    }
  }

  /// Próximo hito de clases totales (múltiplos de 10: 10, 20, 30...).
  int get _proximoHito => ((_clasesTotales ~/ 10) + 1) * 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _header(context),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            children: [
                              _cardObjetivo(),
                              const SizedBox(height: 12),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _cardConstancia()),
                                    const SizedBox(width: 10),
                                    Expanded(child: _cardRecord()),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _cardRitmo(),
                              const SizedBox(height: 12),
                              _cardBienestar(),
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

  // ───────────────────────── Header ─────────────────────────
  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _kLila,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bar_chart_rounded,
              color: _kVioletaOscuro, size: 22),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Mi recorrido',
            style: TextStyle(
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
        const SizedBox(width: 12),
      ],
    );
  }

  // ─────────────── Card 1: clases del mes vs objetivo ───────────────
  Widget _cardObjetivo() {
    final faltan = math.max(0, _objetivoMes - _clasesMes);
    final progreso =
        _objetivoMes == 0 ? 0.0 : (_clasesMes / _objetivoMes).clamp(0.0, 1.0);

    String titulo;
    String detalle;
    if (_objetivoMes == 0) {
      titulo = '¡Te esperamos!';
      detalle = 'Todavía no tenés clases programadas este mes.';
    } else if (faltan == 0) {
      titulo = '¡Objetivo cumplido!';
      detalle = 'Completaste todas tus clases del mes.';
    } else {
      titulo = '¡Vas muy bien!';
      detalle = faltan == 1
          ? 'Estás a 1 clase de cumplir tu objetivo.'
          : 'Estás a $faltan clases de cumplir tu objetivo.';
    }

    return _Card(
      color: _kLilaSuave,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _AnilloPainter(
                progreso: progreso,
                color: _kVioleta,
                fondo: _kGrisAnillo,
                grosor: 9,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_clasesMes',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'clases',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'de $_objetivoMes objetivo',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _kVioletaOscuro,
                        ),
                      ),
                    ),
                    const Icon(Icons.favorite_border,
                        color: _kVerdeAgua, size: 22),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kLila.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up,
                          color: _kVioletaOscuro, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRÓXIMO OBJETIVO',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: _kVioletaOscuro,
                              ),
                            ),
                            Text(
                              '$_proximoHito clases',
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _kVioletaOscuro,
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
        ],
      ),
    );
  }

  // ─────────────── Card 2: constancia (% asistencia) ───────────────
  Widget _cardConstancia() {
    final pct = _asistenciaPct;
    String titulo;
    String detalle;
    if (pct == null) {
      titulo = '¡Arrancamos!';
      detalle = 'Tu constancia aparece después de tus primeras clases.';
    } else if (pct >= 80) {
      titulo = '¡Excelente trabajo!';
      detalle = 'Sos muy constante.\nSeguí así 💪';
    } else if (pct >= 50) {
      titulo = '¡Muy bien!';
      detalle = 'Cada clase suma.\nSeguí así 💪';
    } else {
      titulo = '¡Vamos!';
      detalle = 'Retomá tu ritmo,\nte esperamos 💜';
    }

    return _Card(
      color: _kVerdeAguaSuave,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Etiqueta('TU CONSTANCIA'),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 104,
              height: 104,
              child: CustomPaint(
                painter: _AnilloPainter(
                  progreso: (pct ?? 0) / 100,
                  color: _kVerdeAgua,
                  fondo: _kGrisAnillo,
                  grosor: 7,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pct == null ? '-' : '$pct%',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const Text(
                        'asistencia',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _kVerdeAgua,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Card 3: récord ───────────────
  Widget _cardRecord() {
    final empezaste = _inicio == null
        ? '-'
        : '${_meses[_inicio!.month - 1]} ${_inicio!.year}';

    return _Card(
      color: _kLilaSuave,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Etiqueta('TU RÉCORD'),
          const SizedBox(height: 10),
          _FilaRecord(
            icon: Icons.calendar_month_outlined,
            titulo: 'Empezaste',
            valor: empezaste,
          ),
          _FilaRecord(
            icon: Icons.bar_chart_rounded,
            titulo: 'Clases realizadas',
            valor: '$_clasesTotales',
          ),
          _FilaRecord(
            icon: Icons.emoji_events_outlined,
            titulo: 'Mejor mes',
            valor: _mejorMesLabel ?? '-',
          ),
          _FilaRecord(
            icon: Icons.local_fire_department,
            iconColor: Colors.deepOrange,
            titulo: 'Racha actual',
            valor: _rachaSemanas == 1 ? '1 semana' : '$_rachaSemanas semanas',
          ),
        ],
      ),
    );
  }

  // ─────────────── Card 4: ritmo semanal ───────────────
  Widget _cardRitmo() {
    return _Card(
      color: _kLilaSuave,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_heart_outlined,
                color: _kVioletaOscuro),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Etiqueta('TU RITMO', color: _kVioletaOscuro),
              const SizedBox(height: 2),
              Text(
                _rachaSemanas == 1 ? '1 semana' : '$_rachaSemanas semanas',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const Text(
                'de racha activa',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _ultimasSemanas
                    .map((ok) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: ok ? _kVioleta : _kGrisAnillo,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 14, color: Colors.white),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                _rachaSemanas > 0 ? '¡Seguís sumando!' : '¡Volvé a sumar!',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────── Card 5: mi bienestar ───────────────
  Widget _cardBienestar() {
    return _Card(
      color: _kLilaSuave,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa_outlined, color: _kVioletaOscuro),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Etiqueta('MI BIENESTAR', color: _kVioletaOscuro),
                SizedBox(height: 2),
                Text(
                  'Pilates es mi momento para mí 💜',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    color: Colors.black87,
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

// ───────────────────────── Widgets auxiliares ─────────────────────────

class _Card extends StatelessWidget {
  final Color color;
  final EdgeInsets padding;
  final Widget child;

  const _Card({
    required this.color,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String text;
  final Color color;
  const _Etiqueta(this.text, {this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }
}

class _FilaRecord extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titulo;
  final String valor;

  const _FilaRecord({
    required this.icon,
    required this.titulo,
    required this.valor,
    this.iconColor = _kVioletaOscuro,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kLila.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

/// Anillo de progreso con puntas redondeadas (como en el diseño).
class _AnilloPainter extends CustomPainter {
  final double progreso; // 0..1
  final Color color;
  final Color fondo;
  final double grosor;

  _AnilloPainter({
    required this.progreso,
    required this.color,
    required this.fondo,
    required this.grosor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = (math.min(size.width, size.height) - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final pFondo = Paint()
      ..color = fondo
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    canvas.drawCircle(centro, radio, pFondo);

    if (progreso <= 0) return;
    final pArco = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = grosor;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progreso, false, pArco);
  }

  @override
  bool shouldRepaint(covariant _AnilloPainter old) =>
      old.progreso != progreso || old.color != color;
}
