import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'api/api.dart';
import 'pages/login_page.dart';
import 'pages/agenda_page.dart';
import 'pages/pagos_page.dart';
import 'pages/novedades_page.dart';
import 'pages/notificaciones_page.dart';
import 'pages/mi_recorrido_page.dart';
import 'pages/terms_page.dart';
import 'widgets/social_footer.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Foto de perfil: se guarda SOLO en el dispositivo de la socia (no se
/// sube al backend), por eso alcanza con un archivo local + esta clave
/// en SharedPreferences con la ruta a ese archivo.
const _kFotoPerfilPref = 'foto_perfil_local';

// Colores del Home
const _kVerdeAgua = Color(0xFF00A69B);   // verde agua del logo (antes bordó)
const _kVioleta = Color(0xFF8B6FC9);     // contenido de las 4 tarjetas
const _kTextoHome = Colors.black;        // textos que antes estaban en azul
const _kFondoTarjeta = Color(0xFFECEEED); // gris claro de las 4 tarjetas
const double _kAltoTarjeta = 165;        // mismo alto para las 4 tarjetas

enum _AccionFoto { camara, galeria, quitar }

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

  // Perfil y recorrido del Home: se piden una sola vez y se comparten
  // entre las tarjetas (evita pedirle lo mismo varias veces al backend).
  Future<Map<String, dynamic>>? _perfilFuture;
  Future<Map<String, dynamic>>? _recorridoFuture;

  // Ruta al archivo local de la foto de perfil (null = todavía no eligió
  // ninguna). Vive solo en este dispositivo.
  String? _fotoLocalPath;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _setupFCM();
    }
    _cargarFotoLocal();
    Api.token.then((t) {
      if (!mounted) return;
      setState(() {
        _token = t;
        _authChecked = true;
      });
      if (t != null) _checkTerminos();
    });
  }

  Future<void> _cargarFotoLocal() async {
    final sp = await SharedPreferences.getInstance();
    final path = sp.getString(_kFotoPerfilPref);
    if (path != null && await File(path).exists()) {
      if (mounted) setState(() => _fotoLocalPath = path);
    }
  }

  /// Deja elegir una foto de perfil (cámara o galería). Se guarda una
  /// copia en el almacenamiento local de la app y solo la ruta en
  /// SharedPreferences: nunca se sube al backend, es solo para esta socia
  /// en este dispositivo.
  Future<void> _elegirFoto() async {
    final accion = await showModalBottomSheet<_AccionFoto>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, _AccionFoto.camara),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, _AccionFoto.galeria),
            ),
            if (_fotoLocalPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(ctx, _AccionFoto.quitar),
              ),
          ],
        ),
      ),
    );

    if (accion == null) return; // cerró el menú sin elegir nada

    if (accion == _AccionFoto.quitar) {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kFotoPerfilPref);
      if (mounted) setState(() => _fotoLocalPath = null);
      return;
    }

    final origen =
        accion == _AccionFoto.camara ? ImageSource.camera : ImageSource.gallery;

    XFile? file;
    try {
      file = await ImagePicker()
          .pickImage(source: origen, imageQuality: 80, maxWidth: 800);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo acceder a la foto: $e')),
      );
      return;
    }
    if (file == null) return; // canceló el picker

    final dir = await getApplicationDocumentsDirectory();
    final destino = '${dir.path}/foto_perfil_local.jpg';
    await File(file.path).copy(destino);

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFotoPerfilPref, destino);

    if (mounted) setState(() => _fotoLocalPath = destino);
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

  // Refresca los datos del Home (perfil, próxima clase, recorrido).
  // Se usa al volver de otra pantalla (ej. Pagos) para que tarjetas como
  // "Mi plan de pago" no se queden mostrando el dato que había cuando se
  // abrió la app la primera vez (el perfil se pedía una sola vez y nunca
  // se volvía a consultar).
  void _refrescarHome() {
    if (!mounted) return;
    setState(() {
      _perfilFuture = Api.getPerfil();
      _proximaClaseFuture = _fetchProximaClase();
      _recorridoFuture = Api.getRecorrido();
    });
  }

  // Navegación a secciones
  void _goAgenda() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendaPage()),
    );
    _refrescarHome();
  }

  void _goPagos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PagosPage()),
    );
    _refrescarHome();
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

  void _goMiRecorrido() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MiRecorridoPage()),
    );
    _refrescarHome();
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
    _perfilFuture ??= Api.getPerfil();
    _recorridoFuture ??= Api.getRecorrido();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        // CustomScrollView + SliverFillRemaining: si el contenido entra en
        // la pantalla, los botones de redes quedan pegados abajo de todo;
        // si no entra, se scrollea normalmente y quedan al final.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _HomeHeader(
                    perfilFuture: _perfilFuture!,
                    onNotificaciones: _goNotificaciones,
                    onLogout: _onLogout,
                  ),
                  const SizedBox(height: 12),

                  _PerfilCard(
                    perfilFuture: _perfilFuture!,
                    fotoLocalPath: _fotoLocalPath,
                    onTapFoto: _elegirFoto,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: _kAltoTarjeta,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ProximaClaseCard(
                            future: _proximaClaseFuture!,
                            onTap: _goAgenda,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PlanPagoCard(
                            perfilFuture: _perfilFuture!,
                            onTap: _goPagos,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: _kAltoTarjeta,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ProgresoCard(
                            recorridoFuture: _recorridoFuture!,
                            onTap: _goMiRecorrido,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NovedadesCard(onTap: _goNovedades),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [SocialFooter()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decoración común de las 4 tarjetas del Home (mismo fondo gris claro).
BoxDecoration _decoTarjeta() => BoxDecoration(
      color: _kFondoTarjeta,
      borderRadius: BorderRadius.circular(20),
    );

/// Título común de las 4 tarjetas del Home (ícono + texto, más grande).
class _TituloTarjeta extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;

  const _TituloTarjeta({required this.icon, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        // Si el título no entra en una línea (pantallas angostas), se
        // achica un poco en vez de cortarse.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
            texto,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          ),
        ),
      ],
    );
  }
}

// ======================= WIDGETS HOME =======================

/// Encabezado del Home: saludo + logo + campanita de notificaciones +
/// cerrar sesión (sin el subtítulo "¿Lista/o para tu momento de pilates?").
class _HomeHeader extends StatelessWidget {
  final Future<Map<String, dynamic>> perfilFuture;
  final VoidCallback onNotificaciones;
  final VoidCallback onLogout;

  const _HomeHeader({
    required this.perfilFuture,
    required this.onNotificaciones,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
      children: [
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: perfilFuture,
            builder: (context, snap) {
              String saludo = 'Hola! 👋';
              if (snap.hasData) {
                final nombre = (snap.data!['nombre'] ?? '').toString().trim();
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
          child: Image.asset(
            'assets/logo.jpeg',
            width: 38,
            height: 38,
            fit: BoxFit.cover,
          ),
        ),
        IconButton(
          onPressed: onNotificaciones,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notificaciones',
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
        ),
      ],
        ),
        const SizedBox(height: 4),
        // Ilustración de la cama de Pilates (reformer) en el encabezado.
        Image.asset('assets/reformer.png', height: 90, fit: BoxFit.contain),
      ],
    );
  }
}

/// Tarjeta de perfil: foto (local, editable), nombre, número de socia y
/// tres datos rápidos (sede, fecha de ingreso y días desde que ingresó).
class _PerfilCard extends StatelessWidget {
  final Future<Map<String, dynamic>> perfilFuture;
  final String? fotoLocalPath;
  final VoidCallback onTapFoto;

  const _PerfilCard({
    required this.perfilFuture,
    required this.fotoLocalPath,
    required this.onTapFoto,
  });

  String _formatFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  int? _diasDesdeIngreso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return DateTime.now().difference(dt).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: perfilFuture,
      builder: (context, snap) {
        final p = snap.data;
        final nombreCompleto = p == null
            ? ''
            : '${(p['nombre'] ?? '').toString().trim()} ${(p['apellido'] ?? '').toString().trim()}'
                .trim();
        final numero = p?['numero']?.toString() ?? '-';
        final sede = (p?['sede'] ?? '').toString();
        final inicioIso = p?['inicio_clases']?.toString();
        final desde = _formatFecha(inicioIso);
        final dias = _diasDesdeIngreso(inicioIso);

        return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFE5D4F9),
                          backgroundImage: fotoLocalPath != null
                              ? FileImage(File(fotoLocalPath!))
                              : null,
                          child: fotoLocalPath == null
                              ? const Icon(Icons.person,
                                  size: 34, color: Color(0xFF9D84D0))
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: InkWell(
                            onTap: onTapFoto,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _kVerdeAgua,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombreCompleto.isEmpty ? '—' : nombreCompleto,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: _kTextoHome,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nro. de Socia',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kVerdeAgua,
                            ),
                          ),
                          Text(
                            numero,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatMini(
                        icon: Icons.location_on_outlined,
                        label: 'SEDE',
                        value: sede.isEmpty ? '-' : sede,
                      ),
                    ),
                    Container(width: 1, height: 32, color: Colors.black12),
                    Expanded(
                      child: _StatMini(
                        icon: Icons.calendar_today_outlined,
                        label: 'DESDE',
                        value: desde,
                      ),
                    ),
                    Container(width: 1, height: 32, color: Colors.black12),
                    Expanded(
                      child: _StatMini(
                        icon: Icons.spa_outlined,
                        label: 'DÍAS EN ETNYA',
                        value: dias != null ? '$dias' : '-',
                      ),
                    ),
                  ],
                ),
              ],
            ),
        );
      },
    );
  }
}

/// Un dato chico (icono + etiqueta + valor), usado en la fila de
/// Sede / Desde / Días en Etnya de la tarjeta de perfil.
class _StatMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatMini({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: _kVerdeAgua),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Georgia',
            color: _kTextoHome,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta "Próxima clase" del Home, con datos reales de la API.
class _ProximaClaseCard extends StatelessWidget {
  final Future<Map<String, dynamic>?> future;
  final VoidCallback onTap;

  const _ProximaClaseCard({required this.future, required this.onTap});

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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 90,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }

            final clase = snap.data;
            if (clase == null) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TituloTarjeta(
                    icon: Icons.calendar_today,
                    texto: 'Mis Clases',
                    color: _kTextoHome,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sin clases próximas agendadas',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _kVioleta,
                    ),
                  ),
                ],
              );
            }

            final dt = clase['_fecha'] as DateTime;
            final hora =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TituloTarjeta(
                  icon: Icons.calendar_today,
                  texto: 'Mis Clases',
                  color: _kTextoHome,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Próxima clase',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  _labelFecha(dt),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                    color: _kVioleta,
                  ),
                ),
                Text(
                  '$hora hs',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kVioleta,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta "Mi plan de pago": modalidad del socio y próximo vencimiento
/// (en verde si está al día, en rojo si está en mora), con acceso a Pagos.
class _PlanPagoCard extends StatelessWidget {
  final Future<Map<String, dynamic>> perfilFuture;
  final VoidCallback onTap;

  const _PlanPagoCard({required this.perfilFuture, required this.onTap});

  String _formatFecha(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: perfilFuture,
          builder: (context, snap) {
            final p = snap.data;
            final plan = (p?['tipo_clase'] ?? '').toString().trim();
            final planLabel = plan.isEmpty ? 'Mi plan' : plan.split('-').first.trim();
            final vencStr = (p?['proximo_vencimiento'] ?? '').toString();
            final alDia = (p?['estado_pago'] ?? '').toString() == 'al_dia';
            final colorEstado =
                alDia ? _kVioleta : const Color(0xFFD9534F); // rojo solo si está en mora

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TituloTarjeta(
                  icon: Icons.credit_card,
                  texto: 'Mi plan de pago',
                  color: _kTextoHome,
                ),
                const SizedBox(height: 8),
                Text(
                  planLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                    color: _kVioleta,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Próximo vencimiento',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
                Text(
                  vencStr.isEmpty ? '-' : _formatFecha(vencStr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorEstado,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver detalles',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kVioleta,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 14, color: _kVioleta),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta "Progreso": días practicando Pilates en Etnya. Lleva a
/// "Mi recorrido" para el detalle completo.
class _ProgresoCard extends StatelessWidget {
  final Future<Map<String, dynamic>> recorridoFuture;
  final VoidCallback onTap;

  const _ProgresoCard({required this.recorridoFuture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: recorridoFuture,
          builder: (context, snap) {
            final diasPracticando = snap.data?['dias_practicando'] as int?;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TituloTarjeta(
                  icon: Icons.trending_up,
                  texto: 'Progreso',
                  color: _kTextoHome,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation(_kVioleta),
                          backgroundColor: Color(0xFFE5D4F9),
                        ),
                      ),
                      Text(
                        diasPracticando != null ? '$diasPracticando' : '-',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kVioleta,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Días practicando Pilates con nosotras',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    color: _kVioleta,
                    height: 1.2,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta "Novedades": acceso directo a las noticias de Etnya.
class _NovedadesCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NovedadesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TituloTarjeta(
              icon: Icons.campaign_outlined,
              texto: 'Novedades',
              color: _kTextoHome,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enterate de todo lo nuevo en Etnya 💜',
              style: TextStyle(fontSize: 13, color: _kVioleta, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}