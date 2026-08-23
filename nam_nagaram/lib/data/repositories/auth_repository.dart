import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).getUserData(user.uid);
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = UserModel(
        id: credential.user!.uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        phoneVerified: true, // Temporarily bypassed OTP
        role: 'citizen',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.id).set(user.toMap());

      return credential;
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Phone Authentication
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> linkPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Link the phone credential to the current email user
        await user.linkWithCredential(credential);
        
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'phoneVerified': true,
        });
      } else {
         throw Exception('No user currently signed in to link phone.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
          // It's already linked, just update firestore
          final u = _firebaseAuth.currentUser;
          if(u != null) {
            await _firestore.collection('users').doc(u.uid).update({
              'phoneVerified': true,
            });
          }
      } else if (e.code == 'credential-already-in-use') {
         // This phone number is linked to another account. 
         // In a real app, handle merging or reject. Here we throw.
         throw Exception('Phone number already in use by another account.');
      }
      else {
        throw Exception('Failed to link phone: $e');
      }
    } catch (e) {
      throw Exception('Failed to link phone: $e');
    }
  }
}
