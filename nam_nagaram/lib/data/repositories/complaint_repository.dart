import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/complaint_model.dart';
import '../models/timeline_model.dart';
import 'auth_repository.dart';
import '../services/ai_verification_service.dart';

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ComplaintRepository(
    firestore: FirebaseFirestore.instance,
  );
});

final userComplaintsProvider = StreamProvider<List<ComplaintModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(complaintRepositoryProvider).getUserComplaints(user.uid);
});

final teamComplaintsProvider = StreamProvider<List<ComplaintModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || user.teamId == null) return Stream.value([]);
      return ref.watch(complaintRepositoryProvider).getTeamComplaints(user.teamId!);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final complaintTimelineProvider = StreamProvider.family<List<TimelineModel>, String>((ref, complaintId) {
  return ref.watch(complaintRepositoryProvider).getComplaintTimeline(complaintId);
});

class ComplaintRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  ComplaintRepository({
    required FirebaseFirestore firestore,
  })  : _firestore = firestore;

  Future<String> uploadImage(File image, String complaintId, String userId) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  Future<void> submitComplaint({
    required String userId,
    required String assetType,
    required String issueType,
    required String description,
    required File imageFile,
    required double latitude,
    required double longitude,
    required String address,
    required String citizenPriority,
    String? watermarkedBase64,
  }) async {
    try {
      final complaintId = _uuid.v4();
      
      // 1. Upload Image (Use watermark if provided by server, else convert raw file)
      final imageUrl = watermarkedBase64 ?? await uploadImage(imageFile, complaintId, userId);

      // Removed mock auto-dispatch so the Python backend (agent_worker.py) can 
      // pick it up, assign it, and send the native FCM Push Notifications!
      String status = 'Submitted';
      String? autoAssignedTeamId;

      // 2. Create Complaint Document
      final complaint = ComplaintModel(
        id: complaintId,
        userId: userId,
        assetType: assetType,
        issueType: issueType,
        description: description,
        imageUrl: imageUrl,
        latitude: latitude,
        longitude: longitude,
        address: address,
        citizenPriority: citizenPriority,
        status: status,
        assignedTeamId: autoAssignedTeamId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Batch Write: Create complaint and initial timeline entry
      final batch = _firestore.batch();
      
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      batch.set(complaintRef, complaint.toMap());

      final timelineId = _uuid.v4();
      final timelineRef = complaintRef.collection('timeline').doc(timelineId);
      final timeline = TimelineModel(
        id: timelineId,
        status: 'Submitted',
        message: 'Your complaint has been received.',
        timestamp: DateTime.now(),
        updatedBy: userId,
      );
      batch.set(timelineRef, timeline.toMap());

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to submit complaint: $e');
    }
  }

  Stream<List<ComplaintModel>> getUserComplaints(String userId) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ComplaintModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<ComplaintModel>> getTeamComplaints(String teamId) {
    return _firestore
        .collection('complaints')
        .where('status', whereIn: ['Team Assigned', 'Work In Progress', 'Resolved', 'Closed'])
        .snapshots()
        .map((snapshot) {
      final complaints = snapshot.docs.map((doc) => ComplaintModel.fromMap(doc.data(), doc.id)).toList();
      
      int getPriorityWeight(String? priority) {
        switch (priority) {
          case 'Critical': return 4;
          case 'High': return 3;
          case 'Medium': return 2;
          case 'Low': return 1;
          default: return 0;
        }
      }

      complaints.sort((a, b) {
        final aWeight = getPriorityWeight(a.aiPriorityLevel);
        final bWeight = getPriorityWeight(b.aiPriorityLevel);
        
        if (aWeight != bWeight) {
          return bWeight.compareTo(aWeight); // Higher priority first
        }
        return b.createdAt.compareTo(a.createdAt); // Newer first if same priority
      });
      
      return complaints;
    });
  }

  Stream<ComplaintModel> getComplaint(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .snapshots()
        .map((doc) => ComplaintModel.fromMap(doc.data()!, doc.id));
  }

  Stream<List<TimelineModel>> getComplaintTimeline(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TimelineModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> resolveComplaint({
    required String complaintId,
    required String assetType,
    required File imageFile,
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      // 1. Verify Resolution Image using AI & request Geotag Watermark
      final verificationResult = await aiVerificationService.verifyResolutionImage(
        imageFile, 
        assetType,
        latitude: latitude.toString(),
        longitude: longitude.toString(),
        address: address,
      );
      
      if (verificationResult['valid'] != true) {
        throw Exception(verificationResult['message'] ?? 'Image verification failed.');
      }

      // 2. Upload Resolution Image (Use watermark if provided, else convert raw)
      final String? watermarkedBase64 = verificationResult['watermarked_base64'];
      final resolutionImageUrl = watermarkedBase64 ?? await uploadImage(imageFile, complaintId, '${userId}_resolved');

      final batch = _firestore.batch();
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      
      // 2. Update Complaint
      batch.update(complaintRef, {
        'status': 'Resolved',
        'resolutionImageUrl': resolutionImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Add Timeline Event
      final timelineId = _uuid.v4();
      final timelineRef = complaintRef.collection('timeline').doc(timelineId);
      final timeline = TimelineModel(
        id: timelineId,
        status: 'Resolved',
        message: 'The issue has been resolved by the assigned crew.',
        timestamp: DateTime.now(),
        updatedBy: userId,
      );
      batch.set(timelineRef, timeline.toMap());

      // 4. Notify the Citizen
      final complaintDoc = await complaintRef.get();
      final reporterId = complaintDoc.data()?['userId'];
      if (reporterId != null) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': reporterId,
          'title': 'Issue Resolved! 🎉',
          'body': 'Your reported $assetType issue has been repaired by the crew. Tap to view and rate their work!',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'complaintId': complaintId,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to resolve complaint: $e');
    }
  }

  Future<void> submitRating({
    required String complaintId,
    required int rating,
    required String comment,
    required String? assignedTeamId,
  }) async {
    try {
      final batch = _firestore.batch();
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      
      batch.update(complaintRef, {
        'rating': rating,
        'ratingComment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify the crew unconditionally (fixes older test complaints missing a team)
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'teamId': assignedTeamId ?? 'unknown_team',
        'title': 'Got $rating stars for this work! ⭐',
        'body': comment.isNotEmpty ? 'Citizen comment: "$comment"' : 'Great job! The citizen was happy with your work.',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'complaintId': complaintId,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }
}
