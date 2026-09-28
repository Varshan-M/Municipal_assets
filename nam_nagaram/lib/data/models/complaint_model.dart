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
  final String? aiPriorityLevel;
  final String? aiPriorityReason;
  final int? slaHours;
  
  // AI Scheduling Agent fields
  final String? schedulingStatus;
  final String? scheduledDate;
  final String? scheduledStartTime;
  final String? expectedCompletionTime;
  final num? travelDistance;
  final int? estimatedTravelTime;
  final String? requiredSkill;
  final int? estimatedRepairDuration;
  
  final String status; // 'Submitted', 'Under Review', 'AI Analysed', 'Verified', 'Team Assigned', 'Work In Progress', 'Resolved', 'Rejected', 'Duplicate'
  final String? assignedTeamId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolutionImageUrl;
  final int? rating;
  final String? ratingComment;

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
    this.aiPriorityLevel,
    this.aiPriorityReason,
    this.slaHours,
    this.schedulingStatus,
    this.scheduledDate,
    this.scheduledStartTime,
    this.expectedCompletionTime,
    this.travelDistance,
    this.estimatedTravelTime,
    this.requiredSkill,
    this.estimatedRepairDuration,
    this.status = 'Submitted',
    this.assignedTeamId,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionImageUrl,
    this.rating,
    this.ratingComment,
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
      aiPriorityLevel: map['aiPriorityLevel'],
      aiPriorityReason: map['aiPriorityReason'],
      slaHours: map['slaHours']?.toInt(),
      schedulingStatus: map['schedulingStatus'],
      scheduledDate: map['scheduledDate'],
      scheduledStartTime: map['scheduledStartTime'],
      expectedCompletionTime: map['expectedCompletionTime'],
      travelDistance: map['travelDistance'] as num?,
      estimatedTravelTime: map['estimatedTravelTime']?.toInt(),
      requiredSkill: map['requiredSkill'],
      estimatedRepairDuration: map['estimatedRepairDuration']?.toInt(),
      status: map['status'] ?? 'Submitted',
      assignedTeamId: map['assignedTeamId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolutionImageUrl: map['resolutionImageUrl'],
      rating: map['rating']?.toInt(),
      ratingComment: map['ratingComment'],
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
      'aiPriorityLevel': aiPriorityLevel,
      'aiPriorityReason': aiPriorityReason,
      'slaHours': slaHours,
      'schedulingStatus': schedulingStatus,
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'expectedCompletionTime': expectedCompletionTime,
      'travelDistance': travelDistance,
      'estimatedTravelTime': estimatedTravelTime,
      'requiredSkill': requiredSkill,
      'estimatedRepairDuration': estimatedRepairDuration,
      'status': status,
      'assignedTeamId': assignedTeamId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolutionImageUrl': resolutionImageUrl,
      'rating': rating,
      'ratingComment': ratingComment,
    };
  }
}
