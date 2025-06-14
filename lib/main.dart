import 'package:firebase_core/firebase_core.dart';
import 'package:scanny/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:scanny/themes/light_mode.dart';
import 'package:scanny/auth/auth_gate.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error initializing cameras: ${e.description}');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Scanny",
      home: const Authgate(),
      theme: lightTheme,
    );
  }
}
