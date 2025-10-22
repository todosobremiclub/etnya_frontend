import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class Api {
  static const _base = 'https://etnya.onrender.com';
  static const _kToken = 'jwt';

  static Future<void> saveToken(String t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, t);
  }
  static Future<String?> get token async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }
  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
  }

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<AuthResponse> login({required String numero, required String apellido}) async {
  final res = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: _headers(null),
    body: jsonEncode({'numero': numero, 'apellido': apellido}), // <-- CAMBIO
  );
  if (res.statusCode >= 200 && res.statusCode < 300) {
    final j = jsonDecode(res.body);
    final r = AuthResponse.fromJson(j);
    await saveToken(r.token);
    return r;
  }
  throw Exception('Login inválido (${res.statusCode})');
}


  static Future<Perfil> getPerfil() async {
    final t = await token;
    final res = await http.get(Uri.parse('$_base/app/perfil'), headers: _headers(t));
    if (res.statusCode == 200) return Perfil.fromJson(jsonDecode(res.body));
    throw Exception('Error perfil');
  }

  static Future<ClasesResp> getClases(String mes) async {
    final t = await token;
    final res = await http.get(Uri.parse('$_base/app/clases?mes=$mes'), headers: _headers(t));
    if (res.statusCode == 200) return ClasesResp.fromJson(jsonDecode(res.body));
    throw Exception('Error clases');
  }

  static Future<List<Novedad>> getNovedades() async {
    final t = await token;
    final res = await http.get(Uri.parse('$_base/app/novedades'), headers: _headers(t));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => Novedad.fromJson(e)).toList();
    }
    throw Exception('Error novedades');
  }

  static Future<List<Noti>> getNotificaciones() async {
    final t = await token;
    final res = await http.get(Uri.parse('$_base/app/notificaciones'), headers: _headers(t));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => Noti.fromJson(e)).toList();
    }
    throw Exception('Error notificaciones');
  }
}
