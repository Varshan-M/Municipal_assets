import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class GeotagCamera extends StatefulWidget {
  const GeotagCamera({super.key});

  @override
  State<GeotagCamera> createState() => _GeotagCameraState();
}

class _GeotagCameraState extends State<GeotagCamera> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  
  Position? _currentPosition;
  String _address = "Locating...";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startLocationUpdates();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0], // Use back camera
          ResolutionPreset.low,
          enableAudio: false,
        );
        
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isReady = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _address = "GPS Disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() => _address = "Permission Denied");
        return;
      }
    }

    // Get initial position quickly
    try {
      Position initialPos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _updateAddress(initialPos);
    } catch (e) {
      debugPrint("Location error: $e");
    }

    // Then listen for live updates
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5)
    ).listen((Position position) {
      _updateAddress(position);
    });
  }

  Future<void> _updateAddress(Position position) async {
    if (!mounted) return;
    setState(() => _currentPosition = position);
    
    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (mounted) {
          setState(() {
            _address = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
          });
        }
      }
    } catch (e) {
      // Ignore geocoding errors during live updates
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile photo = await _controller!.takePicture();
      // Return the file and the latest position back to the caller
      if (mounted) {
        Navigator.pop(context, {
          'file': File(photo.path),
          'position': _currentPosition,
          'address': _address,
        });
      }
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy HH:mm:ss').format(now);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Viewfinder
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Back Button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // GPS Overlay (Like the picture)
          Positioned(
            bottom: 120,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_currentPosition != null)
                    Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}   Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.amber, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Note: Captured by MunicipalAI System',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          
          // Capture Button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 4),
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                  child: Center(
                    child: Container(
                      height: 54,
                      width: 54,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
