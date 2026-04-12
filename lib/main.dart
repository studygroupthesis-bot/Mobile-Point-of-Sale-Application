import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase/firebase_options.dart';
import 'screens/auth/intro_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/transaction/public_receipt_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized');
    } else {
      debugPrint('Firebase already initialized: ${Firebase.apps.first.name}');
    }
  } catch (e, stackTrace) {
    debugPrint('Firebase init error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => const PopPayRoot(),
    ),
  );
}

class PopPayRoot extends StatelessWidget {
  const PopPayRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
      ),
      onGenerateRoute: (settings) {
        final uri = Uri.base;

        debugPrint('Uri.base = $uri');
        debugPrint('Uri.base.path = ${uri.path}');
        debugPrint('Uri.base.queryParameters = ${uri.queryParameters}');

        if (uri.path == '/public-receipt') {
          final storeId = uri.queryParameters['storeId']?.trim();
          final transactionId = uri.queryParameters['transactionId']?.trim();

          if ((storeId?.isNotEmpty ?? false) &&
              (transactionId?.isNotEmpty ?? false)) {
            return MaterialPageRoute(
              builder: (_) => PublicReceiptScreen(
                storeId: storeId!,
                transactionId: transactionId!,
              ),
              settings: const RouteSettings(name: '/public-receipt'),
            );
          }
        }

        if (uri.path == '/reset-password') {
          final oobCode = uri.queryParameters['oobCode']?.trim();
          final email = uri.queryParameters['email']?.trim();

          if (oobCode != null && oobCode.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                oobCode: oobCode,
                email: email,
              ),
              settings: const RouteSettings(name: '/reset-password'),
            );
          }
        }

        return MaterialPageRoute(
          builder: (_) => const IntroScreen(),
          settings: const RouteSettings(name: '/'),
        );
      },
      initialRoute: '/',
    );
  }
}