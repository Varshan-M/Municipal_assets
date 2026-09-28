import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final bool phoneVerified;
  final String role; // 'citizen', 'admin', 'maintenance'
  final String? teamId; // e.g., 'team_alpha' for maintenance role
  final String? profilePictureBase64;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.phoneVerified = false,
    this.role = 'citizen',
    this.teamId,
    this.profilePictureBase64,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      phoneVerified: map['phoneVerified'] ?? false,
      role: map['role'] ?? 'citizen',
      teamId: map['teamId'],
      profilePictureBase64: map['profilePictureBase64'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'phoneVerified': phoneVerified,
      'role': role,
      'teamId': teamId,
      if (profilePictureBase64 != null) 'profilePictureBase64': profilePictureBase64,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? phoneVerified,
    String? profilePictureBase64,
  }) {
    return UserModel(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      role: role,
      teamId: teamId,
      profilePictureBase64: profilePictureBase64 ?? this.profilePictureBase64,
      createdAt: createdAt,
    );
  }
}
