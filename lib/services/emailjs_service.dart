import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJsService {
  static const String serviceId = 'service_bhr4rya';
  static const String templateId = 'template_xnzr7x2';
  static const String publicKey = '03A5IUbW-hDxWpzEz';

  static Future<void> sendAdminCode({
    required String toEmail,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail.trim(),
          'code': code.trim(),
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'EmailJS failed: ${response.statusCode} ${response.body}',
      );
    }
  }
}