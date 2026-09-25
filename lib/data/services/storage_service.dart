import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Cloudinary is used instead of Firebase Storage since Storage now
/// requires a linked billing account (Blaze plan) even for free usage.
/// Use the SAME cloudName/uploadPreset values you already entered in
/// employee_repository.dart, so both files upload to the same account.
class _CloudinaryConfig {
  static const String cloudName = 'rh5fcm3q';
  static const String uploadPreset = 'assisthub_verification';
}

class StorageService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return pickedFile;
  }

  Future<String> uploadProfileImage(String userId, XFile imageFile) async {
    return _uploadImage(imageFile, folder: 'profile_images/$userId');
  }

  Future<String> uploadChatImage(String chatRoomId, XFile imageFile) async {
    return _uploadImage(imageFile, folder: 'chat_images/$chatRoomId');
  }

  Future<String> _uploadImage(XFile imageFile, {required String folder}) async {
    final bytes = await imageFile.readAsBytes();
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${_CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): $body');
    }

    final url = RegExp(r'"secure_url"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
    if (url == null) {
      throw Exception('Cloudinary response missing secure_url: $body');
    }
    return url.replaceAll(r'\/', '/');
  }

  /// Cloudinary deletion requires a signed request with your API secret,
  /// which can't be done safely from the client (it would expose the
  /// secret). Left as a graceful no-op — old images just become orphaned
  /// in your Cloudinary media library rather than actually deleted.
  /// If you need real deletion later, it has to go through a small
  /// backend/Cloud Function that holds the API secret server-side.
  Future<void> deleteImage(String imageUrl) async {
    // Intentionally a no-op for now — see comment above.
  }
}
