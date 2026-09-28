import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../widgets/status_badge.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../widgets/primary_button.dart';
import '../widgets/geotag_camera.dart';
import '../widgets/priority_badge.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String complaintId;

  const ReportDetailScreen({super.key, required this.complaintId});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  File? _resolutionImage;
  File? _barricadeImage;
  Position? _capturedPosition;
  String? _capturedAddress;
  bool _isResolving = false;
  bool _isBarricading = false;
  int _ratingValue = 0;
  final _commentController = TextEditingController();
  bool _isRating = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating(String? teamId) async {
    if (_ratingValue == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a star rating')));
      return;
    }
    setState(() => _isRating = true);
    try {
      await ref.read(complaintRepositoryProvider).submitRating(
        complaintId: widget.complaintId,
        rating: _ratingValue,
        comment: _commentController.text,
        assignedTeamId: teamId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating submitted successfully!')));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  Future<void> _pickResolutionImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GeotagCamera()),
      );
      
      if (result != null && result is Map) {
        setState(() {
          _resolutionImage = result['file'];
          _capturedPosition = result['position'];
          _capturedAddress = result['address'];
        });
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 30,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _resolutionImage = File(pickedFile.path);
        _capturedPosition = null; // reset because gallery image doesn't have live geotag
        _capturedAddress = null;
      });
    }
  }

  Future<void> _pickBarricadeImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GeotagCamera()),
      );
      
      if (result != null && result is Map) {
        setState(() {
          _barricadeImage = result['file'];
        });
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 30,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _barricadeImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _markAsBarricaded() async {
    if (_barricadeImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image showing the barricade')),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isBarricading = true);

    try {
      final repo = ref.read(complaintRepositoryProvider);
      await repo.markAsBarricaded(
        complaintId: widget.complaintId,
        imageFile: _barricadeImage!,
        userId: user.uid,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barricade logged successfully!')),
        );
        setState(() {
          _barricadeImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBarricading = false);
      }
    }
  }

  Future<void> _markAsResolved(String assetType) async {
    if (_resolutionImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image to prove resolution')),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isResolving = true);

    try {
      double latitude = 0.0;
      double longitude = 0.0;
      String address = 'Unknown Location';

      // 1. If we got location from GeotagCamera, use it instantly!
      if (_capturedPosition != null) {
        latitude = _capturedPosition!.latitude;
        longitude = _capturedPosition!.longitude;
        address = _capturedAddress ?? 'Unknown Location';
      } else {
        // Otherwise, fetch it (e.g. they uploaded from gallery)
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Location services are disabled.');

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied.');
        }

        final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
        latitude = position.latitude;
        longitude = position.longitude;
        
        try {
          List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            address = '${place.street}, ${place.subLocality}, ${place.locality}';
          }
        } catch (e) {
          // ignore geocoding errors
        }
      }

      final repo = ref.read(complaintRepositoryProvider);
      await repo.resolveComplaint(
        complaintId: widget.complaintId,
        assetType: assetType,
        imageFile: _resolutionImage!,
        userId: user.uid,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue marked as resolved!')),
        );
        setState(() {
          _resolutionImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaintAsync = ref.watch(complaintRepositoryProvider).getComplaint(widget.complaintId);
    final timelineAsync = ref.watch(complaintTimelineProvider(widget.complaintId));
    final currentUserAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: StreamBuilder(
        stream: complaintAsync,
        builder: (context, complaintSnapshot) {
          if (complaintSnapshot.hasError) return Center(child: Text('Error: ${complaintSnapshot.error}'));
          if (!complaintSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final complaint = complaintSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${complaint.id.substring(0, 8).toUpperCase()}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        StatusBadge(status: complaint.status),
                        const SizedBox(width: 8),
                        PriorityBadge(priority: complaint.aiPriorityLevel),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${complaint.assetType} - ${complaint.issueType}',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(complaint.address, style: theme.textTheme.bodyMedium)),
                  ],
                ),
                if (complaint.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(complaint.description, style: theme.textTheme.bodyMedium),
                ],
                if (complaint.aiPriorityReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('AI Assessment', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(complaint.aiPriorityReason!, style: theme.textTheme.bodySmall),
                        if (complaint.slaHours != null) ...[
                          const SizedBox(height: 4),
                          Text('SLA Target: ${complaint.slaHours} Hours', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ]
                      ],
                    ),
                  ),
                ],
                
                if (complaint.schedulingStatus == 'Scheduled' && complaint.scheduledDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                          theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('AI Workforce Schedule', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SCHEDULED DATE', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                Text(complaint.scheduledDate ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TIME WINDOW', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                Text('${complaint.scheduledStartTime} - ${complaint.expectedCompletionTime}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SLA DEADLINE', style: theme.textTheme.labelSmall?.copyWith(color: Colors.red[700], fontWeight: FontWeight.bold)),
                                Text('${complaint.slaHours} hours', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[700])),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('DISTANCE & TIME', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                Text('${complaint.travelDistance} km (${complaint.estimatedTravelTime} mins)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                
                // --- Barricade Confirmation (Visible to All) ---
                if (complaint.barricadeImageUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Area Secured (Temporary Barricade)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImage(complaint.barricadeImageUrl!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Images Section
                Text('Evidence', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Before', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(complaint.imageUrl),
                          ),
                        ],
                      ),
                    ),
                    if (complaint.resolutionImageUrl != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('After', style: theme.textTheme.labelMedium),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                                child: _buildImage(complaint.resolutionImageUrl!),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // AI Section (Backend driven, placeholder for future)
                if (complaint.aiCategory != null) ...[
                  Text('AI Analysis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detected: ${complaint.aiCategory}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (complaint.aiSeverity != null) Text('Severity: ${complaint.aiSeverity}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Timeline
                Text('Status Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                timelineAsync.when(
                  data: (timelineEvents) {
                    if (timelineEvents.isEmpty) {
                      return const Text('No timeline events yet.');
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: timelineEvents.length,
                      itemBuilder: (context, index) {
                        final event = timelineEvents[index];
                        final isFirst = index == 0;
                        final isLast = index == timelineEvents.length - 1;
                        
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFirst ? theme.colorScheme.primary : Colors.grey[400],
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: isFirst ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.status,
                                        style: TextStyle(
                                          fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                                          color: isFirst ? theme.colorScheme.onSurface : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.message,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp),
                                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Error loading timeline: $err'),
                ),
                
                const SizedBox(height: 24),
                // Crew Action Section
                if ((complaint.status == 'Team Assigned' || complaint.status == 'Work In Progress') && currentUserAsync.value?.role == 'maintenance') ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Crew Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // --- Temporary Barricade Section ---
                  if (complaint.barricadeImageUrl == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Temporary Safety Barricade',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'If this is a high-risk area, please place a safety barricade and upload a photo to secure the area before proceeding.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (_barricadeImage != null)
                            Container(
                              height: 100,
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_barricadeImage!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.camera_alt, size: 16),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade700,
                                    side: BorderSide(color: Colors.orange.shade300),
                                  ),
                                  onPressed: () => _pickBarricadeImage(ImageSource.camera),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.photo_library, size: 16),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade700,
                                    side: BorderSide(color: Colors.orange.shade300),
                                  ),
                                  onPressed: () => _pickBarricadeImage(ImageSource.gallery),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _barricadeImage == null ? null : _markAsBarricaded,
                              child: _isBarricading
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Mark Secured'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_resolutionImage != null)
                    Container(
                      height: 150,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_resolutionImage!),
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
                          onPressed: () => _pickResolutionImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          onPressed: () => _pickResolutionImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Mark Resolved',
                    isLoading: _isResolving,
                    onPressed: _resolutionImage == null ? null : () => _markAsResolved(complaint.assetType),
                  ),
                  const SizedBox(height: 24),
                ],

                // Rating Section
                if (complaint.status == 'Resolved') ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Crew Rating', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  if (complaint.rating != null) ...[
                    // Show existing rating
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < complaint.rating! ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    if (complaint.ratingComment != null && complaint.ratingComment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('"${complaint.ratingComment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ]
                  ] else if (currentUserAsync.value?.role == 'citizen') ...[
                    // Show rating form for citizen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _ratingValue ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                          onPressed: () => setState(() => _ratingValue = index + 1),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Leave a comment for the crew...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Submit Rating',
                      isLoading: _isRating,
                      onPressed: () => _submitRating(complaint.assignedTeamId),
                    ),
                  ] else ...[
                    const Text('No rating given yet.'),
                  ],
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
      );
    }
  }
}
