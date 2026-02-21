import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase/firebase_options.dart';
import 'screens/auth/login_screen.dart'; // ⬅ import login screen
// import 'app/app.dart';  // temporarily disable until after login

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("Firebase apps count: ${Firebase.apps.length}");

  runApp(
    DevicePreview(
      enabled: kIsWeb,
      builder: (context) => const PopPayRoot(),
    ),
  );
}

class PopPayRoot extends StatelessWidget {
  const PopPayRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
      ),
      home: const LoginScreen(), // ⬅ LOGIN NOW LOADS FIRST
    );
  }
}
