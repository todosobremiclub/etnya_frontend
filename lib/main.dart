import 'package:flutter/material.dart';
import 'api/api.dart';
import 'pages/login_page.dart';
import 'pages/perfil_page.dart';
import 'pages/clases_page.dart';
import 'pages/novedades_page.dart';
import 'pages/notificaciones_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EtnyaApp());
}

class EtnyaApp extends StatelessWidget {
  const EtnyaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etnya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
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
  @override
  void initState() {
    super.initState();
    Api.token.then((t) => mounted ? setState(() => _token = t) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return LoginPage(onLogged: () => setState(() {}));
    }
    return const Home();
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _idx = 0;
  final _pages = const [PerfilPage(), ClasesPage(), NovedadesPage(), NotificacionesPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etnya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Api.clearToken();
              if (mounted) Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage(onLogged: (){
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Home()));
                })), (_) => false);
            },
          )
        ],
      ),
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Clases'),
          NavigationDestination(icon: Icon(Icons.article), label: 'Novedades'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Notificaciones'),
        ],
        onDestinationSelected: (i) => setState(() => _idx = i),
      ),
    );
  }
}
