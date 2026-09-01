import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api/api.dart';
import 'pages/login_page.dart';
import 'pages/perfil_page.dart';
import 'pages/agenda_page.dart';
import 'pages/pagos_page.dart';
import 'pages/novedades_page.dart';
import 'pages/notificaciones_page.dart';
import 'pages/mi_recorrido_page.dart';
import 'pages/terms_page.dart';
import 'widgets/social_footer.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// handler de FCM en segundo plano (solo mobile)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📨 Notificación en segundo plano: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('⚠️ Firebase no pudo inicializarse: $e');
      // La app sigue funcionando aunque falle Firebase (sin notificaciones push).
    }
  }

  runApp(const EtnyaApp());
}

class EtnyaApp extends StatelessWidget {
  const EtnyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etnya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7E4C5B),
        scaffoldBackgroundColor: const Color(0xFFF2F7F5),
      ),
      home: const Gate(),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  String? _token;
  bool _authChecked = false; // ya sabemos si había un token guardado

  // null = todavía no consultamos al backend si aceptó los términos;
  // true/false = respuesta ya conocida (se guarda en el backend, no en
  // el dispositivo, así queda registrado quién aceptó).
  bool? _acceptedTerms;

  // Future de la tarjeta "Próxima clase" (se crea una sola vez al entrar al Home)
  Future<Map<String, dynamic>?>? _proximaClaseFuture;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _setupFCM();
    }
    Api.token.then((t) {
      if (!mounted) return;
      setState(() {
        _token = t;
        _authChecked = true;
      });
      if (t != null) _checkTerminos();
    });
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('🔔 Permiso notificaciones: ${settings.authorizationStatus}');
    final token = await messaging.getToken();
    print('🎯 FCM token: $token');
    await messaging.subscribeToTopic('general');

    // Guardamos el token en el backend para poder mandarle a esta socia
    // el recordatorio 1 hora antes de cada clase. Si todavía no inició
    // sesión, Api.saveFcmToken no hace nada (se reintenta al loguearse).
    if (token != null) {
      await Api.saveFcmToken(token);
    }
    messaging.onTokenRefresh.listen((nuevoToken) {
      Api.saveFcmToken(nuevoToken);
    });

    FirebaseMessaging.onMessage.listen((m) {
      final title = m.notification?.title ?? 'Notificación';
      final body = m.notification?.body ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title\n$body'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Le pregunta al backend si esta socia ya aceptó los términos. Se guarda
  /// ahí (no en el dispositivo) para que quede registrado de forma
  /// permanente y no vuelva a preguntarse en otro celular/reinstalación.
  /// Le pregunta al backend si esta socia ya aceptó, dentro del último año,
  /// el formulario de términos, condiciones y riesgos médicos. Se guarda
  /// ahí (no en el dispositivo) para que quede registrado de forma
  /// permanente y no vuelva a preguntarse en otro celular/reinstalación,
  /// y para que el backend pueda hacerlo vencer al año.
  Future<void> _checkTerminos() async {
    if (!mounted) return;
    setState(() => _acceptedTerms = null);
    try {
      final perfil = await Api.getPerfil();
      if (!mounted) return;
      setState(() => _acceptedTerms = perfil['terminos_aceptados'] == true);
    } catch (e) {
      // Si falla la consulta (sin conexión, backend caído, etc.) no
      // bloqueamos el acceso a la app por eso.
      if (!mounted) return;
      setState(() => _acceptedTerms = true);
    }
  }

  Future<void> _onAcceptTerms() async {
    try {
      await Api.aceptarTerminos();
    } catch (_) {
      // si falla el guardado remoto, igual dejamos pasar: no tiene sentido
      // trabar a la socia por un error de red al aceptar los términos.
    }
    if (!mounted) return;
    setState(() => _acceptedTerms = true);
  }

  Future<void> _onRejectTerms() async {
    await Api.logout();
    if (!mounted) return;
    setState(() {
      _token = null;
      _acceptedTerms = null;
    });
  }

  void _onLogout() async {
    await Api.logout();
    if (mounted) setState(() => _token = null);
  }

  // ======== Próxima clase (tarjeta del Home) ========
  Future<Map<String, dynamic>?> _fetchProximaClase() async {
    final now = DateTime.now();
    String ym(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}';

    final mesesAConsultar = <String>{
      ym(now),
      ym(DateTime(now.year, now.month + 1, 1)),
    };

    final candidatas = <Map<String, dynamic>>[];
    for (final m in mesesAConsultar) {
      try {
        final data = await Api.getClases(m);
        final items = (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map));
        candidatas.addAll(items);
      } catch (_) {
        // si falla un mes, seguimos con el resto
      }
    }

    Map<String, dynamic>? mejor;
    DateTime? mejorFecha;

    for (final c in candidatas) {
      DateTime? dt = DateTime.tryParse((c['fecha_hora'] ?? '').toString());
      if (dt == null) {
        final f = DateTime.tryParse((c['fecha'] ?? '').toString());
        final horaStr = (c['hora'] ?? '').toString();
        if (f != null && horaStr.isNotEmpty) {
          final partes = horaStr.split(':');
          final h = int.tryParse(partes[0]) ?? 0;
          final min = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
          dt = DateTime(f.year, f.month, f.day, h, min);
        } else {
          dt = f;
        }
      }
      if (dt == null) continue;
      if (dt.isBefore(now)) continue;

      final estado = (c['estado'] ?? '').toString().toLowerCase();
      if (estado.contains('cancel') || estado.contains('suspend')) continue;

      if (mejorFecha == null || dt.isBefore(mejorFecha)) {
        mejorFecha = dt;
        mejor = {...c, '_fecha': dt};
      }
    }

    // La modalidad real del socio (ej. "Pilates Reformer") vive en su perfil,
    // no en la clase individual (que solo indica normal/recuperación/etc).
    if (mejor != null) {
      try {
        final perfil = await Api.getPerfil();
        mejor['_tipoClase'] =
            (perfil['tipo_clase'] ?? '').toString().trim();
      } catch (_) {
        // si falla, seguimos sin la modalidad
      }
    }

    return mejor;
  }

  // Navegación a secciones
  void _goPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PerfilPage()),
    );
  }

  void _goAgenda() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendaPage()),
    );
  }

  void _goPagos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PagosPage()),
    );
  }

  void _goNovedades() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NovedadesPage()),
    );
  }

  void _goNotificaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesPage()),
    );
  }

  void _goMiRecorrido() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MiRecorridoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1) Todavía no sabemos si había una sesión guardada
    if (!_authChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) No logueado
    if (_token == null) {
      return LoginPage(
        onLogged: () {
          setState(() => _token = 'ok');
          _checkTerminos();
          if (!kIsWeb) {
            // Ahora que hay sesión, reintentamos guardar el token FCM
            // (por si se había obtenido antes de loguearse).
            FirebaseMessaging.instance.getToken().then((t) {
              if (t != null) Api.saveFcmToken(t);
            });
          }
        },
      );
    }

    // 3) Logueado, consultando al backend si ya aceptó los términos
    if (_acceptedTerms == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 4) Logueado pero sin aceptar términos (según el backend)
    if (_acceptedTerms == false) {
      return TermsPage(
        onAccepted: _onAcceptTerms,
        onRejected: _onRejectTerms,
      );
    }

    // 5) Home
    _proximaClaseFuture ??= _fetchProximaClase();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              _Header(onLogout: _onLogout),
              const SizedBox(height: 16),

              _ProximaClaseCard(
                future: _proximaClaseFuture!,
                onTapEstadoPago: _goPagos,
              ),

              const SizedBox(height: 12),

              // Menú principal
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MenuRow(
                      icon: Icons.person_outline,
                      label: 'Perfil',
                      accentColor: const Color(0xFF8ECFB5),
                      onTap: _goPerfil,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.self_improvement,
                      label: 'Clases',
                      accentColor: const Color(0xFF4FBF75),
                      onTap: _goAgenda,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.credit_card,
                      label: 'Pagos',
                      accentColor: const Color(0xFF86D3D3),
                      onTap: _goPagos,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.campaign_outlined,
                      label: 'Novedades',
                      accentColor: const Color(0xFFBBA3EA),
                      onTap: _goNovedades,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.spa_outlined,
                      label: 'Mi recorrido',
                      accentColor: const Color(0xFF9D84D0),
                      onTap: _goMiRecorrido,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.notifications_outlined,
                      label: 'Notificaciones',
                      accentColor: const Color(0xFF6FA8DC),
                      onTap: _goNotificaciones,
                    ),
                  ],
                ),
              ),

              const SocialFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= WIDGETS HOME =======================

class _Header extends StatelessWidget {
  final VoidCallback onLogout;

  const _Header({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 24),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: Api.getPerfil(),
            builder: (context, snap) {
              String saludo = 'Hola! 👋';
              if (snap.hasData) {
                final p = snap.data!;
                final nombre = (p['nombre'] ?? '').toString().trim();
                if (nombre.isNotEmpty) saludo = 'Hola, $nombre 👋';
              }
              return Text(
                saludo,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              );
            },
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
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}

/// Indicador chico y discreto del estado de pago (debajo de "Próxima clase"):
/// signo "$" verde si está al día, rojo si está en mora. Lleva a Pagos.
class _EstadoPagoChip extends StatelessWidget {
  final VoidCallback onTap;

  const _EstadoPagoChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Api.getPerfil(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final estado = (snap.data!['estado_pago'] ?? '').toString();
        final alDia = estado == 'al_dia';
        final color = alDia ? const Color(0xFF4FBF75) : const Color(0xFFD9534F);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.3),
                  ),
                  child: Text(
                    '\$',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  alDia ? 'Al día' : 'En mora',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fila del menú principal del Home (icono + label + flecha, con barra de color)
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // fondo con un tinte suave del color de la sección (en vez de blanco puro)
          color: Color.alphaBlend(accentColor.withOpacity(0.10), Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Georgia',
                  color: Color(0xFF0E3A5D),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta "Próxima clase" del Home, con datos reales de la API.
class _ProximaClaseCard extends StatelessWidget {
  final Future<Map<String, dynamic>?> future;
  final VoidCallback onTapEstadoPago;

  const _ProximaClaseCard({required this.future, required this.onTapEstadoPago});

  String _labelFecha(DateTime dt) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final dia = DateTime(dt.year, dt.month, dt.day);
    final diff = dia.difference(hoy).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return '${names[dt.weekday - 1]} ${dt.day}/${dt.month}';
  }

  /// Nombre de modalidad a mostrar: prioriza la modalidad del socio
  /// (ej. "Pilates Reformer"); si no hay, y la clase tiene un tipo
  /// distinto de "normal" (ej. "recuperación"), muestra ese.
  /// Si la modalidad del socio viene con aclaraciones después de un "-"
  /// (ej. "Pilates Reformer - 2 x semana"), se muestra solo la parte
  /// antes del guion.
  String _tipoAMostrar(Map<String, dynamic> clase) {
    final tipoClaseSocio = (clase['_tipoClase'] ?? '').toString().trim();
    if (tipoClaseSocio.isNotEmpty) {
      return tipoClaseSocio.split('-').first.trim();
    }

    final tipo = (clase['tipo'] ?? '').toString().trim();
    if (tipo.isEmpty || tipo.toLowerCase() == 'normal') return '';
    return tipo[0].toUpperCase() + tipo.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      decoration: BoxDecoration(
        // mismo tono claro que el fondo de la ilustración, para que se vea todo integrado
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 70,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }

          final clase = snap.data;
          if (clase == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.event_available, color: Color(0xFF8B6FC9), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tenés clases próximas agendadas',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF0E3A5D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _EstadoPagoChip(onTap: onTapEstadoPago),
              ],
            );
          }

          final dt = clase['_fecha'] as DateTime;
          final tipo = _tipoAMostrar(clase);
          final hora =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

          return LayoutBuilder(
            builder: (context, constraints) {
              // La ilustración ocupa ~45% del ancho de la tarjeta,
              // acercándose al bloque de la fecha.
              final imgWidth = (constraints.maxWidth * 0.45).clamp(120.0, 190.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.calendar_today,
                                color: Color(0xFF8B6FC9), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'PRÓXIMA CLASE',
                              style: TextStyle(
                                color: Color(0xFF8B6FC9),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_labelFecha(dt)} • $hora hs',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Georgia',
                            color: Color(0xFF0E3A5D),
                          ),
                        ),
                        if (tipo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            tipo,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Georgia',
                              color: Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _EstadoPagoChip(onTap: onTapEstadoPago),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Sin alto fijo ni BoxFit.cover: así no se recorta ninguna
                  // parte de la ilustración (la cama quedaba cortada abajo).
                  Image.asset(
                    'assets/bambu.jpg',
                    width: imgWidth,
                    fit: BoxFit.contain,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}