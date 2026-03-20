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

  print("Firebase apps count: ${Firebase.apps.length}");

  runApp(
    DevicePreview(
      enabled: kDebugMode && kIsWeb,
      builder: (context) => const PopPayRoot(),
    ),
  );
}

class PopPayRoot extends StatelessWidget {
  const PopPayRoot({super.key});

  Map<String, String?> _extractPublicReceiptParamsFromUrl() {
    if (!kIsWeb) {
      return {
        'storeId': null,
        'transactionId': null,
      };
    }

    final directStoreId = Uri.base.queryParameters['storeId']?.trim();
    final directTransactionId =
        Uri.base.queryParameters['transactionId']?.trim();

    if ((directStoreId?.isNotEmpty ?? false) &&
        (directTransactionId?.isNotEmpty ?? false)) {
      return {
        'storeId': directStoreId,
        'transactionId': directTransactionId,
      };
    }

    final fragment = Uri.base.fragment.trim();
    if (fragment.isEmpty) {
      return {
        'storeId': null,
        'transactionId': null,
      };
    }

    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    final uri = Uri.tryParse(normalized);

    final path = uri?.path ?? '';
    if (!path.startsWith('/public-receipt')) {
      return {
        'storeId': null,
        'transactionId': null,
      };
    }

    final storeId = uri?.queryParameters['storeId']?.trim();
    final transactionId = uri?.queryParameters['transactionId']?.trim();

    return {
      'storeId': (storeId != null && storeId.isNotEmpty) ? storeId : null,
      'transactionId': (transactionId != null && transactionId.isNotEmpty)
          ? transactionId
          : null,
    };
  }

  Widget _resolveHome() {
    final params = _extractPublicReceiptParamsFromUrl();
    final storeId = params['storeId'];
    final transactionId = params['transactionId'];

    if (storeId != null && transactionId != null) {
      return PublicReceiptScreen(
        storeId: storeId,
        transactionId: transactionId,
      );
    }

    return const IntroScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
