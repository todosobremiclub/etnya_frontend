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
  Set<int> _mesesPagados = {}; // meses pagados del año actual (1..12)

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

      final anioActual = DateTime.now().year;
      final mesesPagados = <int>{};
      for (final p in pagos) {
        final mesStr = (p['mes_pagado'] ?? '').toString();
        if (mesStr.length >= 7) {
          final anio = int.tryParse(mesStr.substring(0, 4));
          final mes = int.tryParse(mesStr.substring(5, 7));
          if (anio == anioActual && mes != null) {
            mesesPagados.add(mes);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pagos = pagos;
        _mesesPagados = mesesPagados;
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
    final anioActual = DateTime.now().year;
    final mesKey = '$anioActual-${mesNumero.toString().padLeft(2, '0')}';
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
    final anioActual = DateTime.now().year;
    final mesProximoPago = (_proximoVencimiento != null &&
            _proximoVencimiento!.year == anioActual)
        ? _proximoVencimiento!.month
        : null;

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

                  // "Historial de pagos"
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
                      const Text(
                        'Historial de pagos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0E3A5D),
                        ),
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
                      final pagado = _mesesPagados.contains(mesNumero);
                      final esProximoPago = !pagado && mesProximoPago == mesNumero;

                      return _MesCard(
                        index: index,
                        label: label,
                        pagado: pagado,
                        esProximoPago: esProximoPago,
                        fechaVencimiento: esProximoPago ? _fechaCorta(_proximoVencimiento) : null,
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _LeyendaItem(tipo: _LeyendaTipo.pagado, texto: 'Pagado'),
                        _LeyendaItem(tipo: _LeyendaTipo.proximoPago, texto: 'Próximo pago'),
                        _LeyendaItem(tipo: _LeyendaTipo.pendiente, texto: 'Pendiente'),
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

enum _LeyendaTipo { pagado, proximoPago, pendiente }

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
      case _LeyendaTipo.proximoPago:
        indicador = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Color(0xFF3E9C6B), shape: BoxShape.circle),
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

class _MesCard extends StatelessWidget {
  final String label;
  final bool pagado;
  final bool esProximoPago;
  final String? fechaVencimiento;
  final int index;
  final VoidCallback? onTap;

  const _MesCard({
    required this.label,
    required this.pagado,
    required this.esProximoPago,
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
  static const verdeProximo = Color(0xFF1F7A47);

  @override
  Widget build(BuildContext context) {
    final bgColor = esProximoPago
        ? const Color(0xFFBFE9D2)
        : _bgColors[index.clamp(0, _bgColors.length - 1)];

    final colorTexto = esProximoPago ? verdeProximo : (pagado ? violeta : azulPendiente);

    String subtitulo;
    if (pagado) {
      subtitulo = 'Pagado';
    } else if (esProximoPago) {
      subtitulo = 'Próximo pago';
    } else {
      subtitulo = 'Pendiente';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
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
                    fontSize: 9,
                    fontWeight: esProximoPago ? FontWeight.w700 : FontWeight.w500,
                    color: esProximoPago ? verdeProximo : Colors.black54,
                  ),
                ),
                if (esProximoPago && fechaVencimiento != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    fechaVencimiento!,
                    style: const TextStyle(fontSize: 8, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),
          if (pagado)
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
