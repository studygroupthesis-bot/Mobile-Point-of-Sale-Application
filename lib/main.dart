import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'create_item_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPOS App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Firebase Connected')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateItemScreen(),
                ),
              );
            },
            child: const Text("Go to Create Item Screen"),
          ),
        ),
      ),
    );
  }
}
