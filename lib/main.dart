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
import 'pages/terms_page.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _loadingPrefs = true;
  bool _acceptedTerms = false;

  // layout de fichas tipo fichero
  static const double _cardHeight = 90;
  static const double _overlap = 8; // se pisan apenas
  static const int _cardCount = 5;
  static const double _step = _cardHeight - _overlap;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (!kIsWeb) {
      _setupFCM();
    }
    Api.token.then((t) {
      if (mounted) setState(() => _token = t);
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

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final accepted = sp.getBool('accepted_terms_v1') ?? false;
    if (!mounted) return;
    setState(() {
      _acceptedTerms = accepted;
      _loadingPrefs = false;
    });
  }

  Future<void> _onAcceptTerms() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('accepted_terms_v1', true);
    if (!mounted) return;
    setState(() => _acceptedTerms = true);
  }

  Future<void> _onRejectTerms() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('accepted_terms_v1');
    await Api.logout();
    if (!mounted) return;
    setState(() {
      _token = null;
      _acceptedTerms = false;
    });
  }

  void _onLogout() async {
    await Api.logout();
    if (mounted) setState(() => _token = null);
  }

  // Redes
  Future<void> _openWhatsApp() async {
    const phone = '5491151192428';
    final uri =
        Uri.parse('https://wa.me/$phone?text=Hola%20Etnya%20Pilates');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInstagram() async {
    final uri = Uri.parse(
        'https://www.instagram.com/etnyapilates?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/@etnyapilates6759');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  @override
  Widget build(BuildContext context) {
    // 1) Cargando prefs
    if (_loadingPrefs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) No logueado
    if (_token == null) {
      return LoginPage(onLogged: () => setState(() => _token = 'ok'));
    }

    // 3) Logueado pero sin aceptar términos
    if (!_acceptedTerms) {
      return TermsPage(
        onAccepted: _onAcceptTerms,
        onRejected: _onRejectTerms,
      );
    }

    // 4) Home
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _Header(onLogout: _onLogout),
            const SizedBox(height: 40),

            // Fichas tipo fichero
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: _cardHeight + (_cardCount - 1) * _step,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0 * _step,
                        left: 0,
                        right: 0,
                        child: _MenuCard(
                          text: 'Perfil',
                          colors: const [
                            Color(0xFFA3D8C3),
                            Color(0xFF8ECFB5),
                          ],
                          onTap: _goPerfil,
                        ),
                      ),
                      Positioned(
                        top: 1 * _step,
                        left: 0,
                        right: 0,
                        child: _MenuCard(
                          text: 'Clases',
                          colors: const [
                            Color(0xFF6CCF85),
                            Color(0xFF4FBF75),
                          ],
                          onTap: _goAgenda,
                        ),
                      ),
                      Positioned(
                        top: 2 * _step,
                        left: 0,
                        right: 0,
                        child: _MenuCard(
                          text: 'Pagos',
                          colors: const [
                            Color(0xFFA2E4E4),
                            Color(0xFF86D3D3),
                          ],
                          onTap: _goPagos,
                        ),
                      ),
                      Positioned(
                        top: 3 * _step,
                        left: 0,
                        right: 0,
                        child: _MenuCard(
                          text: 'Novedades',
                          colors: const [
                            Color(0xFFCAB7F0),
                            Color(0xFFBBA3EA),
                          ],
                          onTap: _goNovedades,
                        ),
                      ),
                      Positioned(
                        top: 4 * _step,
                        left: 0,
                        right: 0,
                        child: _MenuCard(
                          text: 'Notificaciones',
                          colors: const [
                            Color(0xFFB19AD9),
                            Color(0xFF9D84D0),
                          ],
                          onTap: _goNotificaciones,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Redes sociales abajo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SocialIcon(
                  background: Colors.white,
                  borderColor: const Color(0xFF25D366),
                  iconColor: const Color(0xFF25D366),
                  icon: FontAwesomeIcons.whatsapp,
                  onTap: _openWhatsApp,
                ),
                const SizedBox(width: 18),
                _SocialIcon(
                  background: Colors.white,
                  borderColor: Colors.pinkAccent,
                  iconColor: Colors.pinkAccent,
                  icon: FontAwesomeIcons.instagram,
                  onTap: _openInstagram,
                ),
                const SizedBox(width: 18),
                _SocialIcon(
                  background: Colors.white,
                  borderColor: Colors.redAccent,
                  iconColor: Colors.redAccent,
                  icon: FontAwesomeIcons.youtube,
                  onTap: _openYoutube,
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
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
              String saludo = 'Hola!';
              if (snap.hasData) {
                final p = snap.data!;
                final nombre = (p['nombre'] ?? '').toString().trim();
                final apellido = (p['apellido'] ?? '').toString().trim();
                final completo = ('$nombre $apellido').trim();
                if (completo.isNotEmpty) saludo = 'Hola $completo!';
              }
              return Text(
                saludo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
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

class _MenuCard extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final VoidCallback onTap;

  const _MenuCard({
    super.key,
    required this.text,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Georgia',
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final Color background;
  final Color borderColor;
  final Color iconColor;
  final FaIconData icon;
  final VoidCallback onTap;

  const _SocialIcon({
    super.key,
    required this.background,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}