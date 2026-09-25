import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, employee, admin }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? address;
  final String? profileImage;
  final UserRole role; // active role for current session
  final List<UserRole> roles; // all roles this user has
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.address,
    this.profileImage,
    required this.role,
    List<UserRole>? roles,
    required this.createdAt,
    required this.updatedAt,
    this.fcmToken,
  }) : roles = roles ?? [role];

  // Check if user has both roles
  bool get isDualRole => roles.length > 1;
  bool get isCustomer => roles.contains(UserRole.customer);
  bool get isEmployee => roles.contains(UserRole.employee);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse roles list
    List<UserRole> rolesList = [];
    if (data['roles'] != null) {
      rolesList = (data['roles'] as List)
          .map((r) => UserRole.values.firstWhere(
                (e) => e.name == r,
                orElse: () => UserRole.customer,
              ))
          .toList();
    }

    // Fallback to single role if roles list is empty
    final singleRole = UserRole.values.firstWhere(
      (e) => e.name == data['role'],
      orElse: () => UserRole.customer,
    );
    if (rolesList.isEmpty) rolesList = [singleRole];

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'],
      address: data['address'],
      profileImage: data['profileImage'],
      role: singleRole,
      roles: rolesList,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'address': address,
      'profileImage': profileImage,
      'role': role.name,
      'roles': roles.map((r) => r.name).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? address,
    String? profileImage,
    UserRole? role,
    List<UserRole>? roles,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}