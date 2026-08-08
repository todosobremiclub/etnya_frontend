// lib/api/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const _base = 'https://etnya.onrender.com';
  static const _kToken = 'jwt';
  static const _kSede = 'sede';

  static Map<String, String> _headers([String? t]) => {
        'Content-Type': 'application/json',
        if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
      };

  // ======== TOKEN ========
  static Future<void> _saveToken(String t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, t);
  }

  static Future<String?> get token async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kSede);
  }

  // ======== LOGIN ========
  static Future<void> login({
    required String numero,
    required String apellido,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: _headers(),
      body: jsonEncode({'numero': numero, 'apellido': apellido}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      final token = j['token'] ?? '';
      if (token.isEmpty) throw Exception('Token vacío');
      await _saveToken(token);

      // guardar la sede del socio si viene en la respuesta
      if (j['socio'] != null && j['socio']['sede'] != null) {
        final sede = j['socio']['sede'].toString().toLowerCase();
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kSede, sede);
        print('✅ Sede guardada en SharedPreferences: $sede');
      } else {
        print('⚠️ No se recibió sede en la respuesta del login.');
      }
      return;
    }
    throw Exception('Login inválido (${res.statusCode})');
  }

  // ======== PERFIL ========
  static Future<Map<String, dynamic>> getPerfil() async {
    final t = await token;
    final res = await http.get(
      Uri.parse('$_base/app/perfil'),
      headers: _headers(t),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Error perfil (${res.statusCode})');
  }

  // ======== PAGOS PROPIOS + RECIBO PDF ========
  static Future<List<dynamic>> getPagosPropios() async {
    final t = await token;
    final res = await http.get(
      Uri.parse('$_base/app/pagos'),
      headers: _headers(t),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is List) ? data : <dynamic>[];
    }
    throw Exception('Error pagos (${res.statusCode})');
  }

  /// URL del comprobante en PDF de un pago propio. Lleva el token como
  /// query param porque se abre como link normal (url_launcher), no como
  /// un fetch con headers.
  static Future<String> reciboPdfUrl(int pagoId) async {
    final t = await token ?? '';
    return '$_base/app/pagos/$pagoId/recibo.pdf?token=${Uri.encodeQueryComponent(t)}';
  }

  // ======== CLASES (mensual) ========
  static Future<Map<String, dynamic>> getClases(String ym) async {
    final t = await token;
    final url = Uri.parse('$_base/app/clases?mes=$ym');
    final res = await http.get(url, headers: _headers(t));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Error clases (${res.statusCode})');
  }

  // ======== AVISAR NO ASISTENCIA (clase futura) ========
  static Future<void> avisarNoAsistencia(int claseId, {String? comentario}) async {
    final t = await token;
    final res = await http.post(
      Uri.parse('$_base/app/clases/$claseId/no-asistira'),
      headers: _headers(t),
      body: jsonEncode({
        if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
      }),
    );
    if (res.statusCode != 200) {
      String msg = 'Error al avisar (${res.statusCode})';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] != null) msg = j['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ======== TÉRMINOS Y CONDICIONES ========
  static Future<void> aceptarTerminos() async {
    final t = await token;
    final res = await http.post(
      Uri.parse('$_base/app/terminos/aceptar'),
      headers: _headers(t),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al aceptar términos (${res.statusCode})');
    }
  }

  // ======== MI RECORRIDO ========
  static Future<Map<String, dynamic>> getRecorrido() async {
    final t = await token;
    final res = await http.get(
      Uri.parse('$_base/app/recorrido'),
      headers: _headers(t),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Error recorrido (${res.statusCode})');
  }

  // ======== TOKEN FCM (notificaciones push) ========
  static Future<void> saveFcmToken(String fcmToken) async {
    final t = await token;
    if (t == null || t.isEmpty) return; // sin sesión, no hay a quién asociarlo
    final res = await http.post(
      Uri.parse('$_base/app/fcm-token'),
      headers: _headers(t),
      body: jsonEncode({'token': fcmToken}),
    );
    if (res.statusCode != 200) {
      print('⚠️ No se pudo guardar el token FCM (${res.statusCode})');
    }
  }

  // ======== NOVEDADES (NOTICIAS) ========
  static Future<List<dynamic>> getNovedades() async {
    final sp = await SharedPreferences.getInstance();
    final sede = sp.getString(_kSede) ?? '';
    final uri = (sede.isEmpty)
        ? Uri.parse('$_base/noticias/para-app')
        : Uri.parse(
            '$_base/noticias/para-app?sede=${Uri.encodeQueryComponent(sede)}');
    print('📰 Cargando novedades para sede: ${sede.isEmpty ? "todas" : sede}');
    final res = await http.get(uri); // sin headers/token
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is List) ? data : <dynamic>[];
    }
    // fallback viejo
    if (res.statusCode == 404) {
      final fb = await http.get(Uri.parse('$_base/app/novedades'));
      if (fb.statusCode == 200) {
        final data = jsonDecode(fb.body);
        return (data is List) ? data : <dynamic>[];
      }
    }
    throw Exception('Error novedades (${res.statusCode})');
  }

  // ======== NOTIFICACIONES ========
  static Future<List<dynamic>> getNotificaciones() async {
    final t = await token;
    final res = await http.get(
      Uri.parse('$_base/app/notificaciones'),
      headers: _headers(t),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Error notificaciones (${res.statusCode})');
  }

  // ======== PAGOS ========
  static Future<List<dynamic>> getPagos() async {
    final res = await http.get(Uri.parse('$_base/pagos'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is List) ? data : <dynamic>[];
    }
    throw Exception('Error pagos (${res.statusCode})');
  }

  // ======== FERIADOS ========
  static Future<List<dynamic>> getFeriados() async {
    final res = await http.get(Uri.parse('$_base/feriados'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is List) ? data : <dynamic>[];
    }
    throw Exception('Error feriados (${res.statusCode})');
  }
}