import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "dqthlji7w"; // verify this is EXACT
  static const String uploadPreset = "pos_app"; // must be UNSIGNED
  static const String folder = "pos/products";

  static const int maxBytes = 5 * 1024 * 1024; // 5MB

  static Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.lengthInBytes > maxBytes) {
      throw Exception("Image too large. Please choose an image under 5MB.");
    }

    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = uploadPreset
      ..fields["folder"] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: filename,
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      try {
        final decoded = jsonDecode(body);
        final msg = decoded["error"]?["message"];
        if (msg != null) throw Exception("Cloudinary upload failed: $msg");
      } catch (_) {}
      throw Exception("Cloudinary upload failed: $body");
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return {
      "secure_url": json["secure_url"],
      "public_id": json["public_id"],
      "bytes": json["bytes"],
      "format": json["format"],
      "width": json["width"],
      "height": json["height"],
    };
  }
}
