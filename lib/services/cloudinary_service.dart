import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String?> uploadToCloudinary(File imageFile) async {
  const cloudName = "dvhzvj5jt";
  const uploadPreset = "rentpay_qr";

  final url =
      Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

  try {
    var request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();
    final res = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}
