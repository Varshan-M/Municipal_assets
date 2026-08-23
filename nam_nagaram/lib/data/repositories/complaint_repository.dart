import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/complaint_model.dart';
import '../models/timeline_model.dart';
import 'auth_repository.dart';

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ComplaintRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

final userComplaintsProvider = StreamProvider<List<ComplaintModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(complaintRepositoryProvider).getUserComplaints(user.uid);
});

final complaintTimelineProvider = StreamProvider.family<List<TimelineModel>, String>((ref, complaintId) {
  return ref.watch(complaintRepositoryProvider).getComplaintTimeline(complaintId);
});

class ComplaintRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  ComplaintRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

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
  }) async {
    try {
      final complaintId = _uuid.v4();
      
      // 1. Upload Image
      final imageUrl = await uploadImage(imageFile, complaintId, userId);

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
        status: 'Submitted',
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
}
