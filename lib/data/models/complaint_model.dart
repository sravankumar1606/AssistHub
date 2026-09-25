import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus { open, resolved }

class ComplaintModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterRole; // 'customer' or 'employee'
  final String subject;
  final String description;
  final String? bookingId;
  final ComplaintStatus status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  ComplaintModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reporterRole,
    required this.subject,
    required this.description,
    this.bookingId,
    this.status = ComplaintStatus.open,
    this.adminResponse,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplaintModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reporterRole: data['reporterRole'] ?? '',
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      bookingId: data['bookingId'],
      status: ComplaintStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ComplaintStatus.open,
      ),
      adminResponse: data['adminResponse'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterRole': reporterRole,
      'subject': subject,
      'description': description,
      'bookingId': bookingId,
      'status': status.name,
      'adminResponse': adminResponse,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}
