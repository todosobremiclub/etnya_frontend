import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

class PagosPage extends StatefulWidget {
  const PagosPage({super.key});

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  bool _loading = true;
  String _estadoPago = ''; // 'al_dia' | 'en_mora'
  DateTime? _proximoVencimiento;

  List<Map<String, dynamic>> _pagos = []; // pagos propios, más reciente primero
  // Meses pagados por año: {2026: {1, 2, 3}, 2025: {...}}
  Map<int, Set<int>> _mesesPagadosPorAnio = {};
  // Fecha de ingreso de la socia: los meses anteriores se muestran grisados.
  DateTime? _fechaIngreso;
  // Año que se está mirando en el historial (por defecto, el actual).
  int _anio = DateTime.now().year;

  final List<String> _mesLabels = const [
    "ENE",
    "FEB",
    "MAR",
    "ABR",
    "MAY",
    "JUN",
    "JUL",
    "AGO",
    "SEP",
    "OCT",
    "NOV",
    "DIC",
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // El perfil (estado de pago, vencimiento) y los pagos se piden por
    // separado: si /app/pagos todavía no existe en el backend desplegado
    // (o falla por lo que sea), igual queremos ver el estado de pago en
    // pantalla en vez de que todo quede en blanco.
    try {
      final perfil = await Api.getPerfil();
      if (!mounted) return;
      final vencStr = (perfil['proximo_vencimiento'] ?? '').toString();
      setState(() {
        _estadoPago = (perfil['estado_pago'] ?? '').toString();
        _fechaIngreso =
            DateTime.tryParse((perfil['inicio_clases'] ?? '').toString());
        _proximoVencimiento = vencStr.isNotEmpty ? DateTime.tryParse(vencStr) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el perfil: $e')),
      );
      return;
    }

    try {
      final pagosRaw = await Api.getPagosPropios();
      final pagos = pagosRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final porAnio = <int, Set<int>>{};
      for (final p in pagos) {
        final mesStr = (p['mes_pagado'] ?? '').toString();
        if (mesStr.length >= 7) {
          final anio = int.tryParse(mesStr.substring(0, 4));
          final mes = int.tryParse(mesStr.substring(5, 7));
          if (anio != null && mes != null) {
            porAnio.putIfAbsent(anio, () => <int>{}).add(mes);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pagos = pagos;
        _mesesPagadosPorAnio = porAnio;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los comprobantes: $e')),
      );
    }
  }

  /// Busca el pago correspondiente a un mes del año actual y muestra el
  /// cupón (fecha, monto, actividad) con la opción de descargar el PDF.
  void _mostrarCupon(int mesNumero) {
    final mesKey = '$_anio-${mesNumero.toString().padLeft(2, '0')}';
    final pago = _pagos.firstWhere(
      (p) => (p['mes_pagado'] ?? '').toString() == mesKey,
      orElse: () => <String, dynamic>{},
    );
    if (pago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encontramos el comprobante de ese mes.')),
      );
      return;
    }

    final fecha = DateTime.tryParse((pago['fecha_pago'] ?? '').toString());
    final monto = _formatMonto(pago['monto']);
    final actividad = (pago['actividad'] ?? '').toString();
    final id = pago['id'] as int?;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cupón de pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha de pago: ${_fechaCorta(fecha)}'),
            const SizedBox(height: 6),
            Text('Actividad: ${actividad.isNotEmpty ? actividad : '-'}'),
            const SizedBox(height: 6),
            Text('Monto: $monto'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (id != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _descargarRecibo(id);
              },
              child: const Text('Descargar PDF'),
            ),
        ],
      ),
    );
  }

  Future<void> _descargarRecibo(int pagoId) async {
    try {
      final url = await Api.reciboPdfUrl(pagoId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el comprobante: $e')),
      );
    }
  }

  Future<void> _abrirWhatsapp() async {
    const phone = '5491151192428';
    final uri = Uri.parse('https://wa.me/$phone?text=Hola%20Etnya%20Pilates');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Primer año que se puede consultar: el de ingreso de la socia (o el
  /// del pago más viejo, si no hay fecha de ingreso).
  int get _primerAnio {
    final anios = <int>[
      if (_fechaIngreso != null) _fechaIngreso!.year,
      ..._mesesPagadosPorAnio.keys,
    ];
    if (anios.isEmpty) return DateTime.now().year;
    return anios.reduce((a, b) => a < b ? a : b);
  }

  /// true si ese mes es anterior al mes de ingreso de la socia.
  bool _esAntesDeIngreso(int anio, int mes) {
    final ingreso = _fechaIngreso;
    if (ingreso == null) return false;
    return anio < ingreso.year || (anio == ingreso.year && mes < ingreso.month);
  }

  String _fechaCorta(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatMonto(dynamic monto) {
    if (monto == null) return '-';
    final n = num.tryParse(monto.toString());
    if (n == null) return monto.toString();
    // separador de miles simple, sin decimales
    final entero = n.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      final posDesdeFinal = entero.length - i;
      buf.write(entero[i]);
      if (posDesdeFinal > 1 && posDesdeFinal % 3 == 1) buf.write('.');
    }
    return '\$ $buf';
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

    final alDia = _estadoPago == 'al_dia';
    final hoy = DateTime.now();
    final mesesPagados = _mesesPagadosPorAnio[_anio] ?? <int>{};
    final puedeIrAtras = _anio > _primerAnio;
    final puedeIrAdelante = _anio < hoy.year;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),

            // HEADER — "Pagos"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4D9F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.credit_card,
                        color: Color(0xFF7A5AA4), size: 15),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pagos',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/logo.jpeg',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                children: [
                  // Estado de pago + próximo vencimiento
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F3EA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alDia ? Icons.check_circle : Icons.error,
                          color: alDia ? const Color(0xFF3E9C6B) : const Color(0xFFD9534F),
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alDia ? 'Estás al día' : 'Tenés un pago pendiente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: alDia ? const Color(0xFF2F8F53) : const Color(0xFFB33A32),
                                ),
                              ),
                              if (_proximoVencimiento != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Próximo vencimiento: ${_fechaCorta(_proximoVencimiento)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.event_note,
                            color: const Color(0xFF3E9C6B).withOpacity(0.35), size: 32),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // "Historial de pagos" + selector de año
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4D9F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.credit_card,
                            color: Color(0xFF7A5AA4), size: 13),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Historial de pagos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E3A5D),
                          ),
                        ),
                      ),
                      _AnioBoton(
                        icon: Icons.chevron_left,
                        onTap: puedeIrAtras ? () => setState(() => _anio--) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_anio',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E3A5D),
                          ),
                        ),
                      ),
                      _AnioBoton(
                        icon: Icons.chevron_right,
                        onTap: puedeIrAdelante ? () => setState(() => _anio++) : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Grilla de 12 meses
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    itemBuilder: (_, index) {
                      final label = _mesLabels[index];
                      final mesNumero = index + 1;
                      final pagado = mesesPagados.contains(mesNumero);
                      final esMesEnCurso =
                          _anio == hoy.year && mesNumero == hoy.month;
                      final esFuturo = _anio > hoy.year ||
                          (_anio == hoy.year && mesNumero > hoy.month);

                      _EstadoMes estado;
                      if (_esAntesDeIngreso(_anio, mesNumero)) {
                        estado = _EstadoMes.antesDeIngreso;
                      } else if (pagado) {
                        estado = _EstadoMes.pagado;
                      } else if (esMesEnCurso) {
                        estado = _EstadoMes.enCurso;
                      } else if (esFuturo) {
                        estado = _EstadoMes.futuro;
                      } else {
                        estado = _EstadoMes.pendiente;
                      }

                      return _MesCard(
                        index: index,
                        label: label,
                        estado: estado,
                        esMesEnCurso: esMesEnCurso,
                        // El abono se paga del 1 al 10 de cada mes.
                        fechaVencimiento: esMesEnCurso
                            ? '10/${mesNumero.toString().padLeft(2, '0')}'
                            : null,
                        onTap: pagado ? () => _mostrarCupon(mesNumero) : null,
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Leyenda
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _LeyendaItem(tipo: _LeyendaTipo.pagado, texto: 'Pagado'),
                        _LeyendaItem(tipo: _LeyendaTipo.enCurso, texto: 'Mes en curso'),
                        _LeyendaItem(tipo: _LeyendaTipo.pendiente, texto: 'Pendiente'),
                        _LeyendaItem(tipo: _LeyendaTipo.antesDeIngreso, texto: 'Antes del ingreso'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Ayuda por WhatsApp
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _abrirWhatsapp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E9F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF25D366), width: 1.5),
                            ),
                            child: const Icon(Icons.chat_bubble_outline,
                                color: Color(0xFF25D366), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '¿Tenés dudas sobre tu pago?\nEscribinos por WhatsApp y te ayudamos.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF3A2E4D)),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
                        ],
                      ),
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
}

// ================== LEYENDA ==================

enum _LeyendaTipo { pagado, enCurso, pendiente, antesDeIngreso }

class _LeyendaItem extends StatelessWidget {
  final _LeyendaTipo tipo;
  final String texto;

  const _LeyendaItem({required this.tipo, required this.texto});

  @override
  Widget build(BuildContext context) {
    Widget indicador;
    switch (tipo) {
      case _LeyendaTipo.pagado:
        indicador = SizedBox(
          width: 12,
          height: 12,
          child: CustomPaint(painter: _DiagonalLinePainter(color: const Color(0xFF7A5AA4))),
        );
        break;
      case _LeyendaTipo.enCurso:
        indicador = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Color(0xFF3E9C6B), shape: BoxShape.circle),
        );
        break;
      case _LeyendaTipo.antesDeIngreso:
        indicador = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Color(0xFFD5D5D5), shape: BoxShape.circle),
        );
        break;
      case _LeyendaTipo.pendiente:
        indicador = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Color(0xFFD6D3EC), shape: BoxShape.circle),
        );
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicador,
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
      ],
    );
  }
}

// ================== WIDGET TARJETA DE MES ==================

enum _EstadoMes { antesDeIngreso, pagado, enCurso, pendiente, futuro }

class _MesCard extends StatelessWidget {
  final String label;
  final _EstadoMes estado;
  final bool esMesEnCurso;
  final String? fechaVencimiento;
  final int index;
  final VoidCallback? onTap;

  const _MesCard({
    required this.label,
    required this.estado,
    required this.esMesEnCurso,
    required this.fechaVencimiento,
    required this.index,
    this.onTap,
  });

  // Paleta de colores pastel por mes (12 valores, fila por fila)
  static const List<Color> _bgColors = <Color>[
    // Fila 1: ENE, FEB, MAR
    Color(0xFFEAE0F7),
    Color(0xFFEAE0F7),
    Color(0xFFEAE0F7),

    // Fila 2: ABR, MAY, JUN
    Color(0xFFF7E0F2),
    Color(0xFFF7E0F2),
    Color(0xFFF7E0F2),

    // Fila 3: JUL, AGO, SEP
    Color(0xFFE0F7EA),
    Color(0xFFE0F7EA),
    Color(0xFFE0F7EA),

    // Fila 4: OCT, NOV, DIC
    Color(0xFFE7EAF7),
    Color(0xFFE7EAF7),
    Color(0xFFE7EAF7),
  ];

  static const violeta = Color(0xFF7A5AA4); // violeta de texto y línea
  static const azulPendiente = Color(0xFF465177);
  static const verdeEnCurso = Color(0xFF3E9C6B);
  static const gris = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    Color bgColor = _bgColors[index.clamp(0, _bgColors.length - 1)];
    Color colorTexto = azulPendiente;
    Color colorSub = Colors.black54;
    String subtitulo = '';

    switch (estado) {
      case _EstadoMes.antesDeIngreso:
        bgColor = const Color(0xFFEDEDED);
        colorTexto = gris;
        colorSub = gris;
        subtitulo = 'Sin actividad';
        break;
      case _EstadoMes.pagado:
        colorTexto = violeta;
        subtitulo = 'Pagado';
        break;
      case _EstadoMes.enCurso:
        // Mes en curso sin pagar: bien destacado.
        bgColor = verdeEnCurso;
        colorTexto = Colors.white;
        colorSub = Colors.white;
        subtitulo = 'A pagar';
        break;
      case _EstadoMes.pendiente:
        subtitulo = 'Pendiente';
        break;
      case _EstadoMes.futuro:
        bgColor = bgColor.withOpacity(0.5);
        colorTexto = azulPendiente.withOpacity(0.6);
        colorSub = Colors.black38;
        subtitulo = '—';
        break;
    }

    final enCursoSinPagar = estado == _EstadoMes.enCurso;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              // El mes en curso siempre lleva borde verde (aunque ya esté
              // pagado) para ubicarlo de un vistazo.
              border: esMesEnCurso
                  ? Border.all(color: verdeEnCurso, width: 2.5)
                  : null,
              boxShadow: enCursoSinPagar
                  ? [
                      BoxShadow(
                        color: verdeEnCurso.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: enCursoSinPagar ? 16 : 14,
                    fontWeight: FontWeight.w800,
                    color: colorTexto,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: enCursoSinPagar ? 11 : 9,
                    fontWeight: enCursoSinPagar ? FontWeight.w700 : FontWeight.w500,
                    color: colorSub,
                  ),
                ),
                if (enCursoSinPagar && fechaVencimiento != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Vence $fechaVencimiento',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          if (estado == _EstadoMes.pagado)
            Positioned.fill(
              child: CustomPaint(
                painter: _DiagonalLinePainter(color: violeta),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flecha para cambiar de año en el historial (deshabilitada en los
/// extremos: año de ingreso / año actual).
class _AnioBoton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _AnioBoton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: habilitado ? const Color(0xFFE5D4F9) : const Color(0xFFEDEDED),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: habilitado ? const Color(0xFF7A5AA4) : Colors.black26,
        ),
      ),
    );
  }
}

// ================== PINTOR PARA LA LÍNEA DIAGONAL ==================
//
// Línea "/" (de abajo a la izquierda hacia arriba a la derecha), igual que
// el ícono de la leyenda "Pagado". Antes iba de arriba-izquierda a
// abajo-derecha ("\"), al revés de lo que muestra la leyenda.
class _DiagonalLinePainter extends CustomPainter {
  final Color color;

  _DiagonalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
