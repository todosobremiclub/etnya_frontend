import 'package:flutter/material.dart';
import '../api/api.dart';
import '../models/models.dart';

class NotificacionesPage extends StatelessWidget {
  const NotificacionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Noti>>(
      future: Api.getNotificaciones(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('Sin notificaciones'));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) {
            final n = list[i];
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(n.titulo),
              subtitle: Text('${n.fecha}\n${n.texto}'),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}
