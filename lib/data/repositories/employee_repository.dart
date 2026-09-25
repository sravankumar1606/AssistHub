import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/employee_model.dart';

/// Cloudinary is used for document/video uploads instead of Firebase
/// Storage, since Storage now requires a linked billing account (Blaze
/// plan) even for free-tier usage. Cloudinary's free tier needs no card.
///
/// Set these to your own values from cloudinary.com — Dashboard for the
/// cloud name, Settings > Upload > Upload presets for the preset name.
class _CloudinaryConfig {
  static const String cloudName = 'rh5fcm3q'; // e.g. 'dxyz123abc'
  static const String uploadPreset = 'assisthub_verification'; // e.g. 'assisthub_verification'
}

class EmployeeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'employees';

  Future<void> createEmployee(EmployeeModel employee) async {
    await _firestore
        .collection(_collection)
        .doc(employee.id)
        .set(employee.toFirestore());
  }

  Future<EmployeeModel?> getEmployee(String employeeId) async {
    final doc = await _firestore.collection(_collection).doc(employeeId).get();
    if (!doc.exists) return null;
    return EmployeeModel.fromFirestore(doc);
  }

  Future<EmployeeModel?> getEmployeeByUserId(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return EmployeeModel.fromFirestore(query.docs.first);
  }

  Stream<EmployeeModel?> employeeStream(String employeeId) {
    return _firestore
        .collection(_collection)
        .doc(employeeId)
        .snapshots()
        .map((doc) => doc.exists ? EmployeeModel.fromFirestore(doc) : null);
  }

  Stream<List<EmployeeModel>> employeesStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => _availableTopRatedFirst(
              snapshot.docs
                  .map((doc) => EmployeeModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Stream<List<EmployeeModel>> employeesByCategoryStream(String category) {
    return _firestore
        .collection(_collection)
        .where('serviceCategory', isEqualTo: category)
        .snapshots()
        .map((snapshot) => _availableTopRatedFirst(
              snapshot.docs
                  .map((doc) => EmployeeModel.fromFirestore(doc))
                  .toList(),
            ));
  }

  Future<List<EmployeeModel>> getTopRatedEmployees({int limit = 10}) async {
    final query = await _firestore.collection(_collection).get();
    return _availableTopRatedFirst(
      query.docs.map((doc) => EmployeeModel.fromFirestore(doc)).toList(),
    ).take(limit).toList();
  }

  Future<List<EmployeeModel>> searchEmployees(String query) async {
    final results = await _firestore.collection(_collection).get();
    
    final searchLower = query.toLowerCase();
    return results.docs
        .map((doc) => EmployeeModel.fromFirestore(doc))
        .where((employee) => employee.isAvailable)
        .where((employee) => employee.verificationStatus == VerificationStatus.approved)
        .where((employee) =>
            employee.name.toLowerCase().contains(searchLower) ||
            employee.serviceCategory.toLowerCase().contains(searchLower) ||
            employee.serviceDetails.toLowerCase().contains(searchLower))
        .toList();
  }

  Future<void> updateEmployee(String employeeId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(_collection).doc(employeeId).update(data);
  }

  Future<void> updateAvailability(String employeeId, bool isAvailable) async {
    await updateEmployee(employeeId, {'isAvailable': isAvailable});
  }

  Future<void> updateRating(String employeeId, double newRating, int totalReviews) async {
    await updateEmployee(employeeId, {
      'rating': newRating,
      'totalReviews': totalReviews,
    });
  }

  Future<void> incrementJobCount(String employeeId) async {
    await _firestore.collection(_collection).doc(employeeId).update({
      'totalJobs': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addEarnings(String employeeId, double amount) async {
    await _firestore.collection(_collection).doc(employeeId).update({
      'totalEarnings': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<EmployeeModel> _availableTopRatedFirst(List<EmployeeModel> employees) {
    final available = employees
        .where((employee) => employee.isAvailable)
        .where((employee) => employee.verificationStatus == VerificationStatus.approved)
        .toList();
    available.sort((a, b) => b.rating.compareTo(a.rating));
    return available;
  }

  /// Unfiltered — every employee regardless of verification status, for
  /// the admin dashboard's Pending/Approved/Rejected tabs. Customer-facing
  /// screens should keep using employeesStream()/employeesByCategoryStream()
  /// instead, which stay filtered to approved-only.
  Stream<List<EmployeeModel>> allEmployeesForAdminStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EmployeeModel.fromFirestore(doc)).toList());
  }

  Future<void> addWorkVideo(String employeeId, String videoUrl) async {
    await _firestore.collection(_collection).doc(employeeId).update({
      'workVideoUrls': FieldValue.arrayUnion([videoUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeWorkVideo(String employeeId, String videoUrl) async {
    await _firestore.collection(_collection).doc(employeeId).update({
      'workVideoUrls': FieldValue.arrayRemove([videoUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Admin: verification workflow ---

  /// Real-time stream of employees awaiting admin review.
  Stream<List<EmployeeModel>> pendingEmployeesStream() {
    return _firestore
        .collection(_collection)
        .where('verificationStatus', isEqualTo: VerificationStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EmployeeModel.fromFirestore(doc)).toList());
  }

  Future<void> approveEmployee(String employeeId) async {
    await updateEmployee(employeeId, {
      'verificationStatus': VerificationStatus.approved.name,
      'rejectionReason': null,
    });
  }

  Future<void> rejectEmployee(String employeeId, String reason) async {
    await updateEmployee(employeeId, {
      'verificationStatus': VerificationStatus.rejected.name,
      'rejectionReason': reason,
    });
  }

  // --- Storage uploads for verification documents/video ---

  /// Uploads a picked document (image or PDF) to Cloudinary and returns
  /// its secure URL. 'auto' resource type lets Cloudinary detect
  /// image vs PDF automatically.
  Future<String> uploadEmployeeDocument({
    required String employeeUserId,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${_CloudinaryConfig.cloudName}/auto/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _CloudinaryConfig.uploadPreset
      ..fields['folder'] = 'employee_documents/$employeeUserId'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

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

  Future<String> uploadEmployeeVideo({
    required String employeeUserId,
    required XFile videoFile,
  }) async {
    final bytes = await videoFile.readAsBytes();
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${_CloudinaryConfig.cloudName}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _CloudinaryConfig.uploadPreset
      ..fields['folder'] = 'employee_videos/$employeeUserId'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: videoFile.name));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary video upload failed (${response.statusCode}): $body');
    }

    final url = RegExp(r'"secure_url"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
    if (url == null) {
      throw Exception('Cloudinary response missing secure_url: $body');
    }
    return url.replaceAll(r'\/', '/');
  }
}
