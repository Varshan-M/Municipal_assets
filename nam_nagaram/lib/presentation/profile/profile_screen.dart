import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/auth_repository.dart';

class ProfileImageNotifier extends Notifier<Map<String, File>> {
  @override
  Map<String, File> build() => {};
  
  void setImage(String userId, File file) {
    state = {...state, userId: file};
  }
}

final profileImageProvider = NotifierProvider<ProfileImageNotifier, Map<String, File>>(() {
  return ProfileImageNotifier();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

const _privacyPolicyText = '''
• Data Collection
Collects name, contact details, GPS/location, photos and issue details.

• Location Usage
Location is used to identify the reported issue location.

• Camera & Media Access
Camera/Gallery access is used for uploading issue evidence.

• Data Processing
Data is used for issue verification, maintenance coordination and status updates.

• Data Access
Report information may be accessed by authorized municipal administrators and maintenance teams.

• Third-Party Sharing
User data will not be sold to third parties.

• Data Security
Appropriate measures will be taken to protect user data.
''';

const _helpSupportText = '''
• How to report a municipal issue
Select the affected asset, choose the problem type, add a photo, provide the location and describe the issue. Submit the report to initiate AI verification and maintenance processing.

• How to track a submitted report
View the current status of your reported issue, from submission and verification to assignment, repair and resolution.

• Help with location/GPS permission
Enable location permission to allow Nam Nagaram to identify and attach the exact location of the reported infrastructure issue.

• Help with camera/gallery and photo upload
Allow camera or gallery access to upload clear images of the issue. Photos help the system verify and understand the reported problem.

• Report incorrect AI detection
If the AI identifies the asset or problem incorrectly, use this option to report the incorrect detection so it can be reviewed.

• Contact Support
For technical issues, account-related concerns or other assistance, contact the Nam Nagaram support team through the provided email or phone number.
📧 Email: support@namnagaram.app
📞 Phone: +91 9360897209
''';

const _termsText = '''
• Accurate Information
Users must provide accurate and relevant information.

• Acceptable Use
False, misleading or abusive reports are not allowed.

• AI Assistance
AI may assist with issue verification, prioritization and maintenance coordination.

• Manual Review
AI results may require human review.

• Service Guarantee
Submitting a report does not guarantee immediate repair.

• Maintenance Priorities
Maintenance depends on priority, resources, availability and safety requirements.

• Service Interruptions
Temporary service interruptions may occur due to technical or network issues.

• Policy Updates
Terms may be updated as Nam Nagaram evolves.
''';

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 400);
    final user = ref.read(currentUserProvider).value;
    if (pickedFile != null && user != null) {
      final file = File(pickedFile.path);
      ref.read(profileImageProvider.notifier).setImage(user.id, file);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      await ref.read(authRepositoryProvider).updateProfilePicture(base64String);
      ref.invalidate(currentUserProvider); // Refresh user model to get the base64 string
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final profileImages = ref.watch(profileImageProvider);
    final theme = Theme.of(context);
    final user = userAsync.value;
    final profileImage = user != null ? profileImages[user.id] : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          title: const Text('Profile'),
        ),
        body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage: profileImage != null 
                          ? FileImage(profileImage) 
                          : (user.profilePictureBase64 != null 
                              ? MemoryImage(base64Decode(user.profilePictureBase64!)) 
                              : null) as ImageProvider?,
                      child: profileImage == null && user.profilePictureBase64 == null
                          ? Text(
                              user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                              style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onPrimary),
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: _showImagePickerBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),
                
                _buildListTile(
                  context, 
                  icon: Icons.person_outline, 
                  title: 'Edit Profile', 
                  onTap: () => _showEditProfileDialog(context, user)
                ),
                _buildListTile(
                  context, 
                  icon: Icons.lock_outline, 
                  title: 'Privacy Policy', 
                  onTap: () => _showInfoDialog(context, 'Privacy Policy', _privacyPolicyText)
                ),
                _buildListTile(
                  context, 
                  icon: Icons.help_outline, 
                  title: 'Help & Support', 
                  onTap: () => _showInfoDialog(context, 'Help & Support', _helpSupportText)
                ),
                _buildListTile(
                  context, 
                  icon: Icons.description_outlined, 
                  title: 'Terms & Conditions', 
                  onTap: () => _showInfoDialog(context, 'Terms & Conditions', _termsText)
                ),
                const SizedBox(height: 24),
                
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Profile', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user.firstName,
              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user.lastName,
              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
