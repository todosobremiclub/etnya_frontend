import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/api.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>> _notificaciones = [];
  bool _cargando = true;
  String _nombre = '';

  static const String _baseUrl = 'https://etnya.onrender.com';

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    _cargarNotificaciones();

    // 🔔 Escuchar notificaciones push en tiempo real
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final titulo = message.notification?.title ?? 'Notificación';
      final cuerpo = message.notification?.body ?? '';
      setState(() {
        _notificaciones.insert(0, {
          'titulo': titulo,
          'mensaje': cuerpo,
          'fecha': DateTime.now().toIso8601String(),
        });
      });
    });
  }

  Future<void> _cargarNombre() async {
    try {
      final perfil = await Api.getPerfil();
      if (!mounted) return;
      setState(() {
        _nombre = (perfil['nombre'] ?? '').toString().trim();
      });
    } catch (e) {
      print('❌ Error al obtener el nombre: $e');
    }
  }

  /// 🔹 Obtener notificaciones guardadas en el backend
  Future<void> _cargarNotificaciones() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/notificaciones'));
      if (res.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        setState(() {
          _notificaciones = data;
          _cargando = false;
        });
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error al obtener notificaciones: $e');
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header: ← Hola nombre!   [logo]
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarNotificaciones,
                      child: _notificaciones.isEmpty
                          ? const Center(child: Text("No hay notificaciones"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _notificaciones.length,
                              itemBuilder: (context, i) {
                                final n = _notificaciones[i];
                                final fecha =
                                    n['fecha'] ?? DateTime.now().toString();
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.notifications_active,
                                      color: Color(0xFF7E4C5B),
                                    ),
                                    title: Text(
                                      n['titulo'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7E4C5B),
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(n['mensaje'] ?? ''),
                                        const SizedBox(height: 4),
                                        Text(
                                          fecha
                                              .toString()
                                              .substring(0, 16)
                                              .replaceAll('T', ' '),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}