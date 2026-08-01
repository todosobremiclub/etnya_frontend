import 'package:flutter/material.dart';
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
  int? _numeroSocia;
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
    try {
      // PERFIL → nombre + número
      final perfil = await Api.getPerfil();
      final nombre = (perfil['nombre'] ?? '').toString().trim();
      final numero = perfil['numero'];

      if (numero == null) {
        throw Exception('El perfil no trae campo "numero".');
      }

      // TODOS los pagos, filtramos por alumno_numero
      final pagos = await Api.getPagos();
      final anioActual = DateTime.now().year;
      final mesesPagados = <int>{};

      for (final p in pagos) {
        if (p['alumno_numero'].toString() == numero.toString()) {
          final mesStr = (p['mes_pagado'] ?? '').toString();
          if (mesStr.length >= 7) {
            final anio = int.tryParse(mesStr.substring(0, 4));
            final mes = int.tryParse(mesStr.substring(5, 7));
            if (anio == anioActual && mes != null) {
              mesesPagados.add(mes);
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _nombre = nombre;
        _numeroSocia = numero;
        _mesesPagados = mesesPagados;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar pagos: $e')),
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

            const SizedBox(height: 20),

            // PANEL PAGOS (verde pastel, como maqueta)
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFA3D8C3), // verde pastel principal
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Pagos",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // ← ahora blanco
                      ),
                    ),

                    const SizedBox(height: 32), // ← más separación con los meses

                    // GRID DE MESES en 3 columnas (como el adjunto)
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 12,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
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
                          );
                        },
                      ),
                    ),
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

// ================== WIDGET TARJETA DE MES ==================

class _MesCard extends StatelessWidget {
  final String label;
  final bool pagado;
  final int index;

  const _MesCard({
    required this.label,
    required this.pagado,
    required this.index,
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

    return Stack(
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
              fontSize: 22,
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