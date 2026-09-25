import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus { pending, approved, rejected }

class EmployeeModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? profileImage;
  final String serviceCategory;
  final String serviceDetails;
  final int experienceYears;
  final double hourlyRate;
  final double rating;
  final int totalReviews;
  final int totalJobs;
  final double totalEarnings;
  final bool isAvailable;
  final List<String> skills;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;
  final List<String> documentUrls;
  final String? videoUrl;
  final List<String> workVideoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.profileImage,
    required this.serviceCategory,
    required this.serviceDetails,
    required this.experienceYears,
    required this.hourlyRate,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.totalJobs = 0,
    this.totalEarnings = 0.0,
    this.isAvailable = true,
    this.skills = const [],
    this.verificationStatus = VerificationStatus.pending,
    this.rejectionReason,
    this.documentUrls = const [],
    this.videoUrl,
    this.workVideoUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => verificationStatus == VerificationStatus.approved;
  bool get isPendingVerification => verificationStatus == VerificationStatus.pending;
  bool get isRejected => verificationStatus == VerificationStatus.rejected;

  factory EmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      profileImage: data['profileImage'],
      serviceCategory: data['serviceCategory'] ?? '',
      serviceDetails: data['serviceDetails'] ?? '',
      experienceYears: data['experienceYears'] ?? 0,
      hourlyRate: (data['hourlyRate'] ?? 0).toDouble(),
      rating: (data['rating'] ?? 0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      totalJobs: data['totalJobs'] ?? 0,
      totalEarnings: (data['totalEarnings'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      skills: List<String>.from(data['skills'] ?? []),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == data['verificationStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      rejectionReason: data['rejectionReason'],
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      videoUrl: data['videoUrl'],
      workVideoUrls: List<String>.from(data['workVideoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'profileImage': profileImage,
      'serviceCategory': serviceCategory,
      'serviceDetails': serviceDetails,
      'experienceYears': experienceYears,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'totalReviews': totalReviews,
      'totalJobs': totalJobs,
      'totalEarnings': totalEarnings,
      'isAvailable': isAvailable,
      'skills': skills,
      'verificationStatus': verificationStatus.name,
      'rejectionReason': rejectionReason,
      'documentUrls': documentUrls,
      'videoUrl': videoUrl,
      'workVideoUrls': workVideoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? profileImage,
    String? serviceCategory,
    String? serviceDetails,
    int? experienceYears,
    double? hourlyRate,
    double? rating,
    int? totalReviews,
    int? totalJobs,
    double? totalEarnings,
    bool? isAvailable,
    List<String>? skills,
    VerificationStatus? verificationStatus,
    String? rejectionReason,
    List<String>? documentUrls,
    String? videoUrl,
    List<String>? workVideoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileImage: profileImage ?? this.profileImage,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      experienceYears: experienceYears ?? this.experienceYears,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalJobs: totalJobs ?? this.totalJobs,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      isAvailable: isAvailable ?? this.isAvailable,
      skills: skills ?? this.skills,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      documentUrls: documentUrls ?? this.documentUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      workVideoUrls: workVideoUrls ?? this.workVideoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
