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
  String _nombre = '';
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
    // El perfil (nombre, estado de pago, vencimiento) y los pagos se piden
    // por separado: si /app/pagos todavía no existe en el backend
    // desplegado (o falla por lo que sea), igual queremos ver el nombre y
    // el estado de pago en pantalla en vez de que todo quede en blanco.
    try {
      final perfil = await Api.getPerfil();
      if (!mounted) return;
      final vencStr = (perfil['proximo_vencimiento'] ?? '').toString();
      setState(() {
        _nombre = (perfil['nombre'] ?? '').toString().trim();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // HEADER — Hola Susana!
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

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Estado de pago + próximo vencimiento
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        left: BorderSide(
                          color: alDia ? const Color(0xFF4FBF75) : const Color(0xFFD9534F),
                          width: 4,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alDia ? Icons.check_circle : Icons.error,
                          color: alDia ? const Color(0xFF4FBF75) : const Color(0xFFD9534F),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alDia ? 'Estás al día' : 'Tenés un pago pendiente',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: alDia ? const Color(0xFF2F8F53) : const Color(0xFFB33A32),
                                ),
                              ),
                              if (_proximoVencimiento != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Próximo vencimiento: ${_fechaCorta(_proximoVencimiento)}',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PANEL PAGOS (verde pastel, como maqueta)
                  // OJO: sin altura fija — antes el Container tenía
                  // "height: 260" y con los 12 meses (4 filas) no entraban,
                  // se veían solo ~6 meses cortados. Ahora el panel crece
                  // según el contenido (shrinkWrap) para que se vean los 12.
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA3D8C3), // verde pastel principal
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Pagos",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 12,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.2,
                          ),
                          itemBuilder: (_, index) {
                            final label = _mesLabels[index];
                            final mesNumero = index + 1;
                            final pagado = _mesesPagados.contains(mesNumero);

                            return _MesCard(
                              index: index,
                              label: label,
                              pagado: pagado,
                              onTap: pagado ? () => _mostrarCupon(mesNumero) : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  // El listado de comprobantes se sacó de acá: ahora se ve
                  // el detalle de cada mes (fecha, actividad, monto y
                  // descarga de PDF) tocando directamente ese mes en la
                  // grilla de arriba, vía _mostrarCupon().
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

// ================== WIDGET TARJETA DE MES ==================

class _MesCard extends StatelessWidget {
  final String label;
  final bool pagado;
  final int index;
  final VoidCallback? onTap;

  const _MesCard({
    required this.label,
    required this.pagado,
    required this.index,
    this.onTap,
  });

  // Paleta de colores pastel por mes (12 valores, fila por fila)
  static const List<Color> _bgColors = <Color>[
    // Fila 1: ENE, FEB, MAR
    Color(0xFFE5D4F9),
    Color(0xFFE5D4F9),
    Color(0xFFE5D4F9),

    // Fila 2: ABR, MAY, JUN
    Color(0xFFF9D4F4),
    Color(0xFFF9D4F4),
    Color(0xFFF9D4F4),

    // Fila 3: JUL, AGO, SEP
    Color(0xFFD4F9E2),
    Color(0xFFD4F9E2),
    Color(0xFFD4F9E2),

    // Fila 4: OCT, NOV, DIC
    Color(0xFFD4E3F9),
    Color(0xFFD4E3F9),
    Color(0xFFD4E3F9),
  ];

  @override
  Widget build(BuildContext context) {
    const violeta = Color(0xFF7A5AA4); // violeta de texto y línea
    final bgColor = _bgColors[index.clamp(0, _bgColors.length - 1)];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: violeta,
                letterSpacing: 1.5,
              ),
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

class _DiagonalLinePainter extends CustomPainter {
  final Color color;

  _DiagonalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // línea de esquina superior izquierda a esquina inferior derecha
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
