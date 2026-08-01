import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          Card(
            child: ListTile(
              leading: Icon(Icons.phone_android_rounded),
              title: Text('Almacenamiento local'),
              subtitle: Text(
                'El perfil, los eventos de sueño, las predicciones y sus '
                'resultados permanecen en este dispositivo.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off_rounded),
              title: Text('Sin transmisión automática'),
              subtitle: Text(
                'La aplicación no usa backend, cuentas, publicidad, analítica, '
                'ubicación ni servicios de rastreo.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.file_download_outlined),
              title: Text('Exportación controlada por el cuidador'),
              subtitle: Text(
                'Desde Ajustes puedes crear un CSV y elegir dónde compartirlo '
                'o guardarlo mediante las funciones del dispositivo.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined),
              title: Text('Eliminación'),
              subtitle: Text(
                'Desde Ajustes puedes eliminar todos los datos locales después '
                'de una confirmación reforzada.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
