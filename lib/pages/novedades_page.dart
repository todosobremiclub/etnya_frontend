import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

class NovedadesPage extends StatefulWidget {
  const NovedadesPage({super.key});

  @override
  State<NovedadesPage> createState() => _NovedadesPageState();
}

class _NovedadesPageState extends State<NovedadesPage> {
  // Cada elemento es un grupo (todas las novedades de una misma categoría).
  late Future<List<List<Map<String, dynamic>>>> _future;

  static const _colorPorDefecto = Color(0xFFD9CBEF); // categorías sin color propio

  @override
  void initState() {
    super.initState();
    _future = _cargarNovedades();
  }

  // Trae las novedades y las agrupa por categoría: primero la categoría con
  // la publicación más reciente, y dentro de cada categoría, la última
  // publicada primero (si hay más de una en la misma categoría, se ven
  // juntas como un carrete deslizable en una sola tarjeta).
  Future<List<List<Map<String, dynamic>>>> _cargarNovedades() async {
    final list = await Api.getNovedades();
    final items = list
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    DateTime fechaDe(Map<String, dynamic> n) =>
        DateTime.tryParse((n['fecha'] ?? '').toString()) ?? DateTime(2000);

    // Agrupar por categoría (id, o "sin categoría" para noticias viejas
    // que todavía no tengan una asignada).
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final n in items) {
      final key = (n['categoria_id'] ?? 'sin_categoria').toString();
      grupos.putIfAbsent(key, () => []).add(n);
    }

    // Más reciente primero, dentro de cada categoría.
    for (final g in grupos.values) {
      g.sort((a, b) => fechaDe(b).compareTo(fechaDe(a)));
    }

    // Categorías ordenadas por su publicación más reciente.
    final claves = grupos.keys.toList()
      ..sort((a, b) =>
          fechaDe(grupos[b]!.first).compareTo(fechaDe(grupos[a]!.first)));

    return [for (final k in claves) grupos[k]!];
  }

  Future<String> _nombre() async {
    try {
      final p = await Api.getPerfil();
      return (p['nombre'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  Color _colorDe(Map<String, dynamic> n) {
    final hex = (n['categoria_color'] ?? '').toString().trim();
    if (hex.isEmpty) return _colorPorDefecto;
    try {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return _colorPorDefecto;
    }
  }

  IconData _iconoDe(String categoria) {
    final n = categoria.toLowerCase();
    if (n.contains('clase')) return Icons.self_improvement;
    if (n.contains('record') || n.contains('feriado')) return Icons.notifications;
    if (n.contains('promo') || n.contains('amig')) return Icons.people_alt;
    if (n.contains('taller') || n.contains('evento')) return Icons.build_circle;
    return Icons.campaign;
  }

  // Arma la tarjeta de una novedad puntual (se usa tanto para categorías
  // con una sola novedad como para cada página del carrete).
  Widget _tarjetaDe({
    required BuildContext context,
    required Map<String, dynamic> n,
    required String categoria,
    required Color color,
    required IconData icono,
  }) {
    final titulo = (n['titulo'] ?? '').toString();
    final texto = (n['texto'] ?? '').toString();
    final vistaPrevia = (n['vista_previa'] ?? '').toString().trim().isNotEmpty
        ? (n['vista_previa'] ?? '').toString()
        : (texto.length > 90 ? '${texto.substring(0, 90)}…' : texto);
    final fecha = (n['fecha'] ?? '').toString();
    final img = (n['imagen_url'] ?? '').toString();

    String fechaLinda = "";
    final d = DateTime.tryParse(fecha);
    if (d != null) {
      fechaLinda =
          "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }

    return _NovedadCard(
      categoria: categoria,
      color: color,
      icono: icono,
      titulo: titulo,
      vistaPrevia: vistaPrevia,
      fecha: fechaLinda,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _DetalleNovedad(
              categoria: categoria,
              color: color,
              titulo: titulo,
              texto: texto,
              fecha: fechaLinda,
              imagenUrl: img,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            FutureBuilder<String>(
              future: _nombre(),
              builder: (context, snap) {
                final nombre = snap.data ?? "";
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          "Hola $nombre!",
                          style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w600,
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
                );
              },
            ),

            const SizedBox(height: 14),

            Expanded(
              child: FutureBuilder<List<List<Map<String, dynamic>>>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final grupos = snap.data!;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB19AD9),
                      borderRadius: BorderRadius.all(Radius.circular(36)),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 2),
                          child: Column(
                            children: [
                              Text(
                                "Novedades",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Georgia',
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Enterate de todo lo nuevo en Etnya",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: grupos.isEmpty
                              ? const Center(
                                  child: Text("Sin novedades.",
                                      style: TextStyle(color: Colors.black54)),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                                  itemCount: grupos.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final grupo = grupos[i];
                                    // Todas las novedades de un grupo comparten
                                    // categoría (mismo color/ícono); si hay más
                                    // de una, se ven juntas en un carrete
                                    // deslizable dentro de una sola tarjeta.
                                    final color = _colorDe(grupo.first);
                                    final categoria =
                                        (grupo.first['categoria_nombre'] ?? 'Novedad').toString();
                                    final icono = _iconoDe(categoria);

                                    if (grupo.length == 1) {
                                      return _tarjetaDe(
                                        context: context,
                                        n: grupo.first,
                                        categoria: categoria,
                                        color: color,
                                        icono: icono,
                                      );
                                    }

                                    return _CarruselNovedades(
                                      itemBuilder: (n) => _tarjetaDe(
                                        context: context,
                                        n: n,
                                        categoria: categoria,
                                        color: color,
                                        icono: icono,
                                      ),
                                      items: grupo,
                                      color: color,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SocialFooter(),
          ],
        ),
      ),
    );
  }
}

// ================== CARRETE (varias novedades de una misma categoría) ==================

class _CarruselNovedades extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Color color;
  final Widget Function(Map<String, dynamic> n) itemBuilder;

  const _CarruselNovedades({
    required this.items,
    required this.color,
    required this.itemBuilder,
  });

  @override
  State<_CarruselNovedades> createState() => _CarruselNovedadesState();
}

class _CarruselNovedadesState extends State<_CarruselNovedades> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => widget.itemBuilder(widget.items[i]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == _index ? 16 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i == _index ? widget.color : widget.color.withOpacity(0.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================== TARJETA DE NOVEDAD ==================

class _NovedadCard extends StatelessWidget {
  final String categoria;
  final Color color;
  final IconData icono;
  final String titulo;
  final String vistaPrevia;
  final String fecha;
  final VoidCallback onTap;

  const _NovedadCard({
    required this.categoria,
    required this.color,
    required this.icono,
    required this.titulo,
    required this.vistaPrevia,
    required this.fecha,
    required this.onTap,
  });

  Color get _colorTexto =>
      color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(color, Colors.white, 0.72),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Decoración: hoja/planta tenue en la esquina
            Positioned(
              right: -4,
              bottom: -4,
              child: Icon(Icons.eco, size: 44, color: color.withOpacity(0.14)),
            ),

            // Cinta/etiqueta (bookmark) arriba a la derecha
            Positioned(
              top: 0,
              right: 14,
              child: _Ribbon(color: color),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge de categoría
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoria.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: _colorTexto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, color: color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fecha.isNotEmpty)
                              Text(
                                fecha,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: color.computeLuminance() > 0.55
                                      ? color.withOpacity(0.9)
                                      : color,
                                ),
                              ),
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Georgia',
                                color: Color(0xFF2B2036),
                              ),
                            ),
                            if (vistaPrevia.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                vistaPrevia,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Ver más',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _colorTexto,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cinta/bookmark en la esquina de la tarjeta.
class _Ribbon extends StatelessWidget {
  final Color color;
  const _Ribbon({required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(width: 16, height: 24, color: color),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width / 2, size.height - size.width / 2.2);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ================== DETALLE DE NOVEDAD ==================

class _DetalleNovedad extends StatelessWidget {
  final String categoria;
  final Color color;
  final String titulo;
  final String texto;
  final String fecha;
  final String imagenUrl;

  const _DetalleNovedad({
    required this.categoria,
    required this.color,
    required this.titulo,
    required this.texto,
    required this.fecha,
    required this.imagenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("", style: TextStyle(fontFamily: 'Georgia')),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagenUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(imagenUrl, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                categoria.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: colorTexto,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (fecha.isNotEmpty)
              Text(
                fecha,
                style: const TextStyle(fontFamily: 'Georgia', color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              style: const TextStyle(fontSize: 17, fontFamily: 'Georgia'),
            ),
          ],
        ),
      ),
    );
  }
}
