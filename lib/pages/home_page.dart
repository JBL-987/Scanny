import 'package:flutter/material.dart';
import 'package:chatta/auth/auth_service.dart';
import 'object_scanner.dart'; // Import ObjectScanner

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  void logout() {
    final _authservice = Authservice();
    _authservice.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Chatta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan Object for labeling'),
          onPressed: () {
            // Navigasi ke ObjectScanner saat tombol ditekan
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ObjectScanner()),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}
