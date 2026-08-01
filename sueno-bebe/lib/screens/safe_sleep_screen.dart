import 'package:flutter/material.dart';

class SafeSleepScreen extends StatelessWidget {
  const SafeSleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orientación de sueño seguro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _InfoCard(
            icon: Icons.bedtime_outlined,
            title: 'Medidas generales',
            items: <String>[
              'Acuesta al bebé boca arriba para cada sueño.',
              'Usa una superficie firme, plana y no inclinada.',
              'Mantén almohadas, juguetes y objetos blandos fuera del espacio de sueño.',
              'Evita el sobreabrigo y controla que no tenga demasiado calor.',
              'Mantén un espacio de sueño separado.',
              'Comparte habitación sin compartir la misma superficie de sueño.',
              'Sigue siempre las indicaciones del pediatra o del equipo de salud.',
            ],
          ),
          SizedBox(height: 12),
          _InfoCard(
            icon: Icons.emergency_outlined,
            title: 'Busca atención urgente ante',
            items: <String>[
              'Dificultad respiratoria.',
              'Pausas respiratorias.',
              'Coloración azulada o anormal.',
              'Dificultad importante para despertar.',
              'Comportamiento inusualmente decaído.',
              'Cualquier situación que preocupe seriamente al cuidador.',
            ],
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Información general'),
              subtitle: Text(
                'Esta información es general y no reemplaza las indicaciones '
                'del pediatra o del equipo de salud.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
