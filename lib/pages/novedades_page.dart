import 'package:flutter/material.dart';
import '../api/api.dart';
import '../models/models.dart';

class NovedadesPage extends StatelessWidget {
  const NovedadesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Novedad>>(
      future: Api.getNovedades(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('Sin novedades'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            return ListTile(
              title: Text(n.titulo),
              subtitle: Text(n.fecha),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: Text(n.titulo),
                  content: SingleChildScrollView(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.imagenUrl != null && n.imagenUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Image.network(n.imagenUrl!, fit: BoxFit.cover),
                        ),
                      Text(n.texto),
                    ],
                  )),
                ));
              },
            );
          },
        );
      },
    );
  }
}
