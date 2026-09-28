import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(FirebaseFirestore.instance);
});

class LocationService {
  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  LocationService(this._firestore);

  Future<bool> _handlePermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return false;
    }

    return true;
  }

  Future<void> startTracking(String teamId) async {
    if (_isTracking) return;

    final hasPermission = await _handlePermissions();
    if (!hasPermission) return;

    _isTracking = true;
    debugPrint('Starting location tracking for team: $teamId');

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 3), // Force update every 3 seconds
            forceLocationManager: true, // Bypasses Google Play Services crash on Oppo/Realme
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          );

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      await _firestore.collection('crews').doc(teamId).update({
        'latitude': initialPosition.latitude,
        'longitude': initialPosition.longitude,
        'isOnline': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('Initial location pushed to Firestore: ${initialPosition.latitude}, ${initialPosition.longitude}');
    } catch (e) {
      debugPrint('Could not fetch initial location (using fallback): $e');
      // FALLBACK for Emulators/Devices without Google Play Services
      await _firestore.collection('crews').doc(teamId).update({
        'latitude': 11.6643, // Salem Center
        'longitude': 78.1460, // Salem Center
        'isOnline': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        debugPrint('Location updated: ${position.latitude}, ${position.longitude}');
        try {
          await _firestore.collection('crews').doc(teamId).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'isOnline': true,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to update location in Firestore: $e');
        }
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      }
    );
  }

  Future<void> stopTracking(String? teamId) async {
    if (!_isTracking) return;
    
    debugPrint('Stopping location tracking');
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;

    if (teamId != null) {
      try {
        await _firestore.collection('crews').doc(teamId).update({
          'isOnline': false,
        });
      } catch (e) {
        debugPrint('Failed to set team offline: $e');
      }
    }
  }
}
