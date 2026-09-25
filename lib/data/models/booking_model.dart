import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  active,
  onTheWay,
  working,
  completed,
  cancelled,
}

class BookingModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final String employeeId;
  final String employeeName;
  final String employeePhone;
  final String serviceCategory;
  final String serviceDetails;
  final DateTime scheduledDate;
  final String scheduledTime;
  final double amount;
  final BookingStatus status;
  final String? notes;
  final String? cancellationReason;
  final bool isInstant;
  final List<String> dismissedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerLatitude,
    this.customerLongitude,
    required this.employeeId,
    required this.employeeName,
    required this.employeePhone,
    required this.serviceCategory,
    required this.serviceDetails,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.amount,
    required this.status,
    this.notes,
    this.cancellationReason,
    this.isInstant = false,
    this.dismissedBy = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// True while an instant booking hasn't been claimed by any employee
  /// yet — still visible/broadcast to everyone in the category.
  bool get isUnclaimedInstant => isInstant && employeeId.isEmpty;

  /// True once the customer has shared a precise GPS pin, rather than
  /// only a typed address.
  bool get hasPreciseLocation => customerLatitude != null && customerLongitude != null;

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      customerLatitude: (data['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (data['customerLongitude'] as num?)?.toDouble(),
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeePhone: data['employeePhone'] ?? '',
      serviceCategory: data['serviceCategory'] ?? '',
      serviceDetails: data['serviceDetails'] ?? '',
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledTime: data['scheduledTime'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      notes: data['notes'],
      cancellationReason: data['cancellationReason'],
      isInstant: data['isInstant'] ?? false,
      dismissedBy: List<String>.from(data['dismissedBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeePhone': employeePhone,
      'serviceCategory': serviceCategory,
      'serviceDetails': serviceDetails,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'scheduledTime': scheduledTime,
      'amount': amount,
      'status': status.name,
      'notes': notes,
      'cancellationReason': cancellationReason,
      'isInstant': isInstant,
      'dismissedBy': dismissedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BookingModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? customerLatitude,
    double? customerLongitude,
    String? employeeId,
    String? employeeName,
    String? employeePhone,
    String? serviceCategory,
    String? serviceDetails,
    DateTime? scheduledDate,
    String? scheduledTime,
    double? amount,
    BookingStatus? status,
    String? notes,
    String? cancellationReason,
    bool? isInstant,
    List<String>? dismissedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeePhone: employeePhone ?? this.employeePhone,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isInstant: isInstant ?? this.isInstant,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusDisplayName {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.active:
        return 'Active';
      case BookingStatus.onTheWay:
        return 'On the Way';
      case BookingStatus.working:
        return 'Working';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}
