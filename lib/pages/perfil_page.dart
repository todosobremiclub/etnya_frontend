import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  Map<String, dynamic>? perfil;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPerfil();
  }

  Future<void> loadPerfil() async {
    final p = await Api.getPerfil();
    print("DEBUG PERFIL --> $p");
    if (mounted) {
      setState(() {
        perfil = p;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Campos del backend
    final nombre = (perfil?['nombre'] ?? '').toString().trim();
    final apellido = (perfil?['apellido'] ?? '').toString().trim();
    final numero = (perfil?['numero'] ?? '').toString(); // Nro de socia
    final sede = (perfil?['sede'] ?? '').toString();
    final tipoClase = (perfil?['tipo_clase'] ?? '').toString(); // texto simple abajo
    final inicioRaw = (perfil?['inicio_clases'] ?? '').toString(); // fecha ISO

    // Formateo de fecha de inicio: 17/7/2010
    String inicio = '-';
    if (inicioRaw.isNotEmpty) {
      try {
        final d = DateTime.parse(inicioRaw);
        inicio = "${d.day}/${d.month}/${d.year}";
      } catch (_) {
        inicio = inicioRaw;
      }
    }

    // Foto: el backend no manda ningún campo de foto, así que mostramos ícono
    const String fotoUrl = '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header: ← Hola Viviana!   [logo]
            Row(
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

            // Panel verde de perfil
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFA3D8C3),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Foto / avatar
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl.isEmpty
                            ? const Icon(Icons.person, size: 52)
                            : null,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        "Perfil",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          // Si quisieras dejarlo blanco como en la maqueta:
                          // color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "$nombre $apellido",
                        style: const TextStyle(
                          fontSize: 19,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Campos en "pastillas" moradas (como imagen 2)
                      _campoPerfil("Nro de Socia", numero),
                      const SizedBox(height: 16),

                      _campoPerfil("Tipo de clase", tipoClase),
                      const SizedBox(height: 16),

                      _campoPerfil("Sede", sede),
                      const SizedBox(height: 16),

                      _campoPerfil("Inicio", inicio),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Footer redes
            const SocialFooter(),
          ],
        ),
      ),
    );
  }
}

/// Campo tipo "pastilla" lila con etiqueta y valor.
/// Ej: [ Nro de Socia   1 ]
Widget _campoPerfil(String etiqueta, String valor) {
  const Color fondoLila = Color(0xFFE5D4F9); // mismo morado/lila que Pagos
  const Color violetaTexto = Color(0xFF7A5AA4);

  final String safeValue = valor.isEmpty ? "-" : valor;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: fondoLila,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: violetaTexto,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          safeValue,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}
