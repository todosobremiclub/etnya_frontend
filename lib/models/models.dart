class AuthResponse {
  final String token;
  AuthResponse({required this.token});
  factory AuthResponse.fromJson(Map<String, dynamic> j) =>
      AuthResponse(token: j['token'] ?? '');
}

class Perfil {
  final String numero, nombre, apellido, inicioClases, estadoPago, tipoClase, sede;
  Perfil({
    required this.numero,
    required this.nombre,
    required this.apellido,
    required this.inicioClases,
    required this.estadoPago,
    required this.tipoClase,
    required this.sede,
  });
  factory Perfil.fromJson(Map<String, dynamic> j) => Perfil(
    numero: j['numero'] ?? '',
    nombre: j['nombre'] ?? '',
    apellido: j['apellido'] ?? '',
    inicioClases: j['inicio_clases'] ?? '',
    estadoPago: j['estado_pago'] ?? '',
    tipoClase: j['tipo_clase'] ?? '',
    sede: j['sede'] ?? '',
  );
}

class Clase {
  final int id;
  final String fecha, sede, tipo;
  final String? estado;
  Clase({required this.id, required this.fecha, required this.sede, required this.tipo, this.estado});
  factory Clase.fromJson(Map<String, dynamic> j) => Clase(
    id: (j['id'] ?? 0) as int,
    fecha: j['fecha'] ?? '',
    sede: j['sede'] ?? '',
    tipo: j['tipo'] ?? '',
    estado: j['estado'],
  );
}

class ResumenClases {
  final int tomadas, suspendidas;
  ResumenClases({required this.tomadas, required this.suspendidas});
  factory ResumenClases.fromJson(Map<String, dynamic> j) =>
      ResumenClases(tomadas: j['tomadas'] ?? 0, suspendidas: j['suspendidas'] ?? 0);
}

class ClasesResp {
  final ResumenClases resumen;
  final List<Clase> items;
  ClasesResp({required this.resumen, required this.items});
  factory ClasesResp.fromJson(Map<String, dynamic> j) => ClasesResp(
    resumen: ResumenClases.fromJson(j['resumen'] ?? {}),
    items: (j['items'] as List? ?? []).map((e) => Clase.fromJson(e)).toList(),
  );
}

class Novedad {
  final int id;
  final String titulo, texto, fecha;
  final String? imagenUrl;
  Novedad({required this.id, required this.titulo, required this.texto, required this.fecha, this.imagenUrl});
  factory Novedad.fromJson(Map<String, dynamic> j) => Novedad(
    id: (j['id'] ?? 0) as int,
    titulo: j['titulo'] ?? '',
    texto: j['texto'] ?? '',
    fecha: j['fecha'] ?? '',
    imagenUrl: j['imagenUrl'],
  );
}

class Noti {
  final int id;
  final String titulo, texto, fecha;
  Noti({required this.id, required this.titulo, required this.texto, required this.fecha});
  factory Noti.fromJson(Map<String, dynamic> j) => Noti(
    id: (j['id'] ?? 0) as int,
    titulo: j['titulo'] ?? '',
    texto: j['texto'] ?? '',
    fecha: j['fecha'] ?? '',
  );
}
