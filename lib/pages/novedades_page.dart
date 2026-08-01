import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

class NovedadesPage extends StatefulWidget {
  const NovedadesPage({super.key});

  @override
  State<NovedadesPage> createState() => _NovedadesPageState();
}

class _NovedadesPageState extends State<NovedadesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  int _pageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _future = _cargarNovedades();
  }

  Future<List<Map<String, dynamic>>> _cargarNovedades() async {
    final list = await Api.getNovedades();
    final items = list
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    items.sort((a, b) {
      final da = DateTime.tryParse((a['fecha'] ?? '').toString()) ?? DateTime(2000);
      final db = DateTime.tryParse((b['fecha'] ?? '').toString()) ?? DateTime(2000);
      return db.compareTo(da);
    });

    return items;
  }

  Future<String> _nombre() async {
    try {
      final p = await Api.getPerfil();
      return (p['nombre'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),

      // ❌ SIN APPBAR
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ✔ HEADER correcto como en Perfil/Pagos
            FutureBuilder<String>(
              future: _nombre(),
              builder: (context, snap) {
                final nombre = snap.data ?? "";
                return Row(
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
                      child: Image.network(
                        'https://etnya.onrender.com/admin-panel/logo.jpeg',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (a, b, c) => const Icon(Icons.image, size: 40),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final novedades = snap.data!;
                  if (novedades.isEmpty) {
                    return const Center(child: Text("Sin novedades."));
                  }

                  return Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB19AD9),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Novedades",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: novedades.length,
                            onPageChanged: (i) {
                              setState(() => _pageIndex = i);
                            },
                            itemBuilder: (_, i) {
                              final n = novedades[i];

                              final titulo = (n['titulo'] ?? '').toString();
                              final texto = (n['texto'] ?? '').toString();
                              final fecha = (n['fecha'] ?? '').toString();
                              final img = (n['imagen_url'] ?? '').toString();

                              String fechaLinda = "";
                              if (fecha.isNotEmpty) {
                                final d = DateTime.tryParse(fecha);
                                if (d != null) {
                                  fechaLinda = "${d.day}/${d.month}/${d.year}";
                                }
                              }

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _DetalleNovedad(
                                        titulo: titulo,
                                        texto: texto,
                                        fecha: fechaLinda,
                                        imagenUrl: img,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD9EFEF),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (fechaLinda.isNotEmpty)
                                        Text(
                                          fechaLinda,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontFamily: 'Georgia',
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      _Typewriter(
                                        text: titulo,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Georgia',
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            novedades.length,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _pageIndex
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
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

class _Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _Typewriter({
    required this.text,
    required this.style,
  });

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<int> _count;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _count = StepTween(begin: 0, end: widget.text.length).animate(_c);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _count,
      builder: (_, __) => Text(
        widget.text.substring(0, _count.value),
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DetalleNovedad extends StatelessWidget {
  final String titulo;
  final String texto;
  final String fecha;
  final String imagenUrl;

  const _DetalleNovedad({
    required this.titulo,
    required this.texto,
    required this.fecha,
    required this.imagenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✔ minimalista
      appBar: AppBar(
        title: const Text("",
            style: TextStyle(fontFamily: 'Georgia')),
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
