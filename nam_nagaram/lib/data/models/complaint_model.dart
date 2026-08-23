import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String id;
  final String userId;
  final String assetType;
  final String issueType;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String address;
  final String citizenPriority; // 'Normal', 'Urgent', 'Critical'
  
  // AI fields (backend driven)
  final String? aiCategory;
  final String? aiSeverity;
  final double? aiConfidence;
  
  final String status; // 'Submitted', 'Under Review', 'AI Analysed', 'Verified', 'Team Assigned', 'Work In Progress', 'Resolved', 'Rejected', 'Duplicate'
  final String? assignedTeamId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolutionImageUrl;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.assetType,
    required this.issueType,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.citizenPriority,
    this.aiCategory,
    this.aiSeverity,
    this.aiConfidence,
    this.status = 'Submitted',
    this.assignedTeamId,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionImageUrl,
  });

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    return ComplaintModel(
      id: id,
      userId: map['userId'] ?? '',
      assetType: map['assetType'] ?? '',
      issueType: map['issueType'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      citizenPriority: map['citizenPriority'] ?? 'Normal',
      aiCategory: map['aiCategory'],
      aiSeverity: map['aiSeverity'],
      aiConfidence: map['aiConfidence']?.toDouble(),
      status: map['status'] ?? 'Submitted',
      assignedTeamId: map['assignedTeamId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolutionImageUrl: map['resolutionImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'assetType': assetType,
      'issueType': issueType,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'citizenPriority': citizenPriority,
      'aiCategory': aiCategory,
      'aiSeverity': aiSeverity,
      'aiConfidence': aiConfidence,
      'status': status,
      'assignedTeamId': assignedTeamId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolutionImageUrl': resolutionImageUrl,
    };
  }
}
