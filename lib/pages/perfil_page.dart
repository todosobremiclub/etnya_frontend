import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Perfil>(
      future: Api.getPerfil(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final p = snap.data!;
        final inicio = p.inicioClases.isEmpty ? '-' : DateFormat('dd/MM/yyyy').format(DateTime.parse(p.inicioClases));
        final isOk = p.estadoPago == 'al_dia' || p.estadoPago == 'becado';
        final chipColor = isOk ? AppTheme.pagoOk : AppTheme.pagoMora;
        final chipText  = isOk ? (p.estadoPago == 'becado' ? 'Becado' : 'Cuota al día') : 'Mora de cuota';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.nombre} ${p.apellido}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 10, children: [
              _item('Nº Socio', p.numero),
              _item('Inicio de clases', inicio),
              _item('Tipo de clase', p.tipoClase),
              _item('Sede', p.sede),
            ]),
            const SizedBox(height: 16),
            Chip(
              label: Text(chipText, style: const TextStyle(color: Colors.white)),
              backgroundColor: chipColor,
            ),
          ]),
        );
      },
    );
  }

  Widget _item(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(value),
    ],
  );
}
