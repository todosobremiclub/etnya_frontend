import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../models/models.dart';

class ClasesPage extends StatefulWidget {
  const ClasesPage({super.key});
  @override
  State<ClasesPage> createState() => _ClasesPageState();
}

class _ClasesPageState extends State<ClasesPage> {
  late DateTime _mes;
  Future<ClasesResp>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mes = DateTime(now.year, now.month);
    _load();
  }

  void _load() {
    final mesKey = DateFormat('yyyy-MM').format(_mes);
    setState(() => _future = Api.getClases(mesKey));
  }

  void _mesActual() {
    final now = DateTime.now();
    _mes = DateTime(now.year, now.month);
    _load();
  }

  void _mesProximo() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);
    _mes = DateTime(next.year, next.month);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = DateFormat('MMMM yyyy', 'es_AR').format(_mes);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(titulo[0].toUpperCase() + titulo.substring(1), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(onPressed: _mesActual, child: const Text('Mes actual')),
              TextButton(onPressed: _mesProximo, child: const Text('Próximo')),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ClasesResp>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              final r = snap.data!;
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Tomadas ${r.resumen.tomadas} — Suspendidas ${r.resumen.suspendidas}'),
                  ),
                  for (final c in r.items) _tile(c),
                ],
              );
            },
          ),
        )
      ],
    );
  }

  Widget _tile(Clase c) {
    final dt = DateTime.tryParse(c.fecha);
    final f = dt == null ? c.fecha : DateFormat('EEE dd/MM HH:mm', 'es_AR').format(dt);
    final tipo = c.tipo == 'recuperacion' ? 'Recuperación' : 'Normal';
    final estado = (c.estado ?? '').isEmpty ? '' : ' — ${c.estado}';
    return ListTile(
      title: Text('$f • ${c.sede}'),
      subtitle: Text('$tipo$estado'),
      leading: Icon(c.tipo == 'recuperacion' ? Icons.restore : Icons.event),
    );
  }
}
