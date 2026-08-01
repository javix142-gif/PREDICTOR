import 'package:flutter/material.dart';

class LimitationsScreen extends StatelessWidget {
  const LimitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Limitaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _Limitation(
            title: 'Depende de los registros',
            body: 'La aplicación no detecta el sueño por sí sola ni inventa despertares. '
                'Los resultados reflejan exclusivamente la información ingresada.',
          ),
          _Limitation(
            title: 'Predicción estadística',
            body: 'La próxima ventana es un intervalo probable, no una instrucción '
                'ni una garantía. Los patrones infantiles pueden cambiar.',
          ),
          _Limitation(
            title: 'Referencias generales',
            body: 'Los rangos por edad se muestran como orientación poblacional. '
                'No se diagnostican trastornos ni se emiten alertas médicas.',
          ),
          _Limitation(
            title: 'Prematuridad',
            body: 'La fecha probable de parto se guarda como antecedente. La '
                'aplicación no realiza ajustes automáticos de edad corregida.',
          ),
          _Limitation(
            title: 'Notificaciones aproximadas',
            body: 'Android puede retrasar recordatorios por ahorro de batería. '
                'La aplicación evita alarmas exactas y permisos innecesarios.',
          ),
        ],
      ),
    );
  }
}

class _Limitation extends StatelessWidget {
  const _Limitation({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
