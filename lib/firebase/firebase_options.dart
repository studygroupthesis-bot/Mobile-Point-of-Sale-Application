import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyC-r6Mr71RFSN1Sz5i-O4sxEwl7Yr4ckLo',
        appId: '1:1044525737065:web:4280c7e9f148b5c2aeeef8',
        messagingSenderId: '1044525737065',
        projectId: 'fir-pos-system',
        authDomain: 'fir-pos-system.firebaseapp.com',
        storageBucket: 'fir-pos-system.firebasestorage.app',
        measurementId: 'G-M5LSX2B2TH', // or remove if you don't have one
      );
    } else if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyC-r6Mr71RFSN1Sz5i-O4sxEwl7Yr4ckLo',
        appId: '1:1044525737065:web:4280c7e9f148b5c2aeeef8',
        messagingSenderId: '1044525737065',
        projectId: 'fir-pos-system',
        storageBucket: 'fir-pos-system.firebasestorage.app',
      );
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }
}
