import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineModel {
  final String id;
  final String status;
  final String message;
  final DateTime timestamp;
  final String updatedBy; // userId or 'system' or 'admin'
  final Map<String, dynamic>? metadata;

  TimelineModel({
    required this.id,
    required this.status,
    required this.message,
    required this.timestamp,
    required this.updatedBy,
    this.metadata,
  });

  factory TimelineModel.fromMap(Map<String, dynamic> map, String id) {
    return TimelineModel(
      id: id,
      status: map['status'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedBy': updatedBy,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
