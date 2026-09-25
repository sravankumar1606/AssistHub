import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';

class ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'complaints';

  Future<void> submitComplaint(ComplaintModel complaint) async {
    await _firestore.collection(_collection).add(complaint.toFirestore());
  }

  /// All complaints, newest first — for the admin dashboard.
  Stream<List<ComplaintModel>> allComplaintsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ComplaintModel.fromFirestore(doc)).toList());
  }

  /// A single reporter's own complaints — for "my complaints" on the
  /// customer/employee side.
  Stream<List<ComplaintModel>> reporterComplaintsStream(String reporterId) {
    return _firestore
        .collection(_collection)
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ComplaintModel.fromFirestore(doc)).toList());
  }

  Future<void> resolveComplaint(String complaintId, String adminResponse) async {
    await _firestore.collection(_collection).doc(complaintId).update({
      'status': ComplaintStatus.resolved.name,
      'adminResponse': adminResponse,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
