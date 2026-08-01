import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>> _notificaciones = [];
  bool _cargando = true;

  static const String _baseUrl = 'https://etnya.onrender.com';

  @override
  void initState() {
    super.initState();
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
      backgroundColor: const Color(0xFFE5F0EA),
      body: _cargando
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
                        final fecha = n['fecha'] ?? DateTime.now().toString();
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n['mensaje'] ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  fecha
                                      .toString()
                                      .substring(0, 16)
                                      .replaceAll('T', ' '),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
