import 'package:flutter/material.dart';
import '../api/api.dart';
import '../widgets/social_footer.dart';

/// "Mi recorrido": estadísticas de práctica de la socia — clases tomadas
/// (mes actual y acumulado histórico), minutos practicados (mes y
/// acumulado) y hace cuántos días practica Pilates con nosotras.
class MiRecorridoPage extends StatefulWidget {
  const MiRecorridoPage({super.key});

  @override
  State<MiRecorridoPage> createState() => _MiRecorridoPageState();
}

class _MiRecorridoPageState extends State<MiRecorridoPage> {
  bool _loading = true;
  String? _error;

  int _clasesMes = 0;
  int _clasesTotales = 0;
  int _minutosMes = 0;
  int _minutosTotales = 0;
  int? _diasPracticando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await Api.getRecorrido();
      if (!mounted) return;
      setState(() {
        _clasesMes = (data['clases_mes'] ?? 0) as int;
        _clasesTotales = (data['clases_totales'] ?? 0) as int;
        _minutosMes = (data['minutos_mes'] ?? 0) as int;
        _minutosTotales = (data['minutos_totales'] ?? 0) as int;
        _diasPracticando = data['dias_practicando'] as int?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu recorrido: $e';
        _loading = false;
      });
    }
  }

  String _minutosLabel(int minutos) {
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '$horas hs' : '$horas hs $resto min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Text(
                    'Mi recorrido',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                const SizedBox(width: 48), // balancea el IconButton de la izquierda
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // Banner "hace X días que practicás"
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 22),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5D4F9),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.spa_outlined,
                                    size: 32,
                                    color: Color(0xFF7A5AA4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _diasPracticando != null
                                        ? '${_diasPracticando!}'
                                        : '-',
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 34,
                                      color: Color(0xFF7A5AA4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'días practicando Pilates con nosotras',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7A5AA4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            const _SectionLabel(text: 'Este mes'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    value: '$_clasesMes',
                                    label: 'Clases tomadas',
                                    icon: Icons.self_improvement,
                                    color: const Color(0xFF4FBF75),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    value: _minutosLabel(_minutosMes),
                                    label: 'Minutos practicados',
                                    icon: Icons.timer_outlined,
                                    color: const Color(0xFF86D3D3),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            const _SectionLabel(text: 'Acumulado'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    value: '$_clasesTotales',
                                    label: 'Clases totales',
                                    icon: Icons.self_improvement,
                                    color: const Color(0xFF9D84D0),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    value: _minutosLabel(_minutosTotales),
                                    label: 'Minutos acumulados',
                                    icon: Icons.timer_outlined,
                                    color: const Color(0xFF9D84D0),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                          ],
                        ),
            ),

            const SocialFooter(),
          ],
        ),
      ),
    );
  }
}

/// Título chico y discreto para separar "Este mes" de "Acumulado",
/// mismo estilo que se usa en la pantalla de Clases.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
        color: Colors.black54,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
