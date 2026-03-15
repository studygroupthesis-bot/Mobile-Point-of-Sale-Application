import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'firebase/firebase_options.dart';
import 'screens/auth/intro_screen.dart';
import 'screens/transaction/public_receipt_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    DevicePreview(
      enabled: kDebugMode && kIsWeb,
      builder: (context) => const PopPayRoot(),
    ),
  );
}

class PopPayRoot extends StatelessWidget {
  const PopPayRoot({super.key});

  String? _extractReceiptTokenFromUrl() {
    if (!kIsWeb) return null;

    final directToken = Uri.base.queryParameters['token']?.trim();
    if (directToken != null && directToken.isNotEmpty) {
      return directToken;
    }

    final fragment = Uri.base.fragment.trim();
    if (fragment.isEmpty) return null;

    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    final uri = Uri.tryParse(normalized);

    final path = uri?.path ?? '';
    if (!path.startsWith('/receipt')) return null;

    final token = uri?.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;

    return token;
  }

  Widget _resolveHome() {
    final receiptToken = _extractReceiptTokenFromUrl();
    if (receiptToken != null) {
      return PublicReceiptScreen(token: receiptToken);
    }

    return const IntroScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
      ),
      home: _resolveHome(),
    );
  }
}
