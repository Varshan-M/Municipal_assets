import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/complaint_repository.dart';
import '../widgets/primary_button.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  int _currentStep = 0;
  
  // Form Data
  String? _selectedAsset;
  String? _selectedIssue;
  File? _imageFile;
  Position? _position;
  String _address = 'Fetching location...';
  final _descriptionController = TextEditingController();
  String _priority = 'Normal';
  
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _assets = ['Street Light', 'Road', 'Garbage Bin', 'Water Pump', 'Water Pipeline', 'Traffic Signal', 'Public Building', 'Other'];
  
  final Map<String, List<String>> _issuesMap = {
    'Road': ['Pothole', 'Crack', 'Waterlogging', 'Road damage', 'Other'],
    'Garbage Bin': ['Overflow', 'Damaged bin', 'Missing bin', 'Illegal dumping', 'Other'],
    'Street Light': ['Not working', 'Flickering', 'Damaged pole', 'Low brightness', 'Other'],
  };

  List<String> get _currentIssues => _issuesMap[_selectedAsset] ?? ['Damaged', 'Not working', 'Other'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 30,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _getLocation() async {
    setState(() => _address = 'Fetching location...');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _address = 'Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _address = 'Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() => _address = 'Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() => _position = position);
      
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
        });
      } else {
        setState(() => _address = 'Location found, but address could not be resolved.');
      }
    } catch (e) {
      setState(() => _address = 'Error fetching location: $e');
    }
  }

  Future<void> _submitReport() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(complaintRepositoryProvider);
      await repo.submitComplaint(
        userId: user.uid,
        assetType: _selectedAsset!,
        issueType: _selectedIssue!,
        description: _descriptionController.text.trim(),
        imageFile: _imageFile!,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        address: _address,
        citizenPriority: _priority,
      );
      
      if (mounted) {
        context.pushReplacement('/my-reports');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _selectedAsset == null) return;
          if (_currentStep == 1 && _selectedIssue == null) return;
          if (_currentStep == 2 && _imageFile == null) return;
          if (_currentStep == 3 && _position == null) {
            _getLocation();
            return;
          }
          
          if (_currentStep < 5) {
            setState(() => _currentStep += 1);
          } else {
            _submitReport();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 5;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: isLast ? 'Submit Report' : 'Continue',
                    isLoading: _isLoading,
                    onPressed: details.onStepContinue,
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ]
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Select Asset Type'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assets.map((asset) {
                final isSelected = _selectedAsset == asset;
                return ChoiceChip(
                  label: Text(asset),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedAsset = selected ? asset : null;
                      _selectedIssue = null; // reset issue
                    });
                  },
                );
              }).toList(),
            ),
          ),
          Step(
            title: const Text('Select Problem'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _selectedAsset == null 
              ? const Text('Please select an asset first.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentIssues.map((issue) {
                    return ChoiceChip(
                      label: Text(issue),
                      selected: _selectedIssue == issue,
                      onSelected: (selected) {
                        setState(() => _selectedIssue = selected ? issue : null);
                      },
                    );
                  }).toList(),
                ),
          ),
          Step(
            title: const Text('Add Photo'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageFile != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Location'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Get Current Location'),
                  onPressed: _getLocation,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 16),
                      Expanded(child: Text(_address)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Details & Priority'),
            isActive: _currentStep >= 4,
            state: _currentStep > 4 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter more details about the problem...',
                  ),
                ),
                const SizedBox(height: 24),
                Text('Urgency', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Normal', label: Text('Normal')),
                    ButtonSegment(value: 'Urgent', label: Text('Urgent')),
                    ButtonSegment(value: 'Critical', label: Text('Critical')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (set) {
                    setState(() => _priority = set.first);
                  },
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Review & Submit'),
            isActive: _currentStep >= 5,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                _buildReviewRow('Asset', _selectedAsset ?? ''),
                _buildReviewRow('Issue', _selectedIssue ?? ''),
                _buildReviewRow('Location', _address),
                _buildReviewRow('Priority', _priority),
                if (_descriptionController.text.isNotEmpty)
                  _buildReviewRow('Description', _descriptionController.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
