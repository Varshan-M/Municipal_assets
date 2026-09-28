import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/auth_repository.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

enum AccountType { citizen, teamMember, newTeam }

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _teamNameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  AccountType _accountType = AccountType.citizen;
  String? _selectedTeamId;
  String? _selectedDomain;
  final List<String> _domains = ['Plumbing', 'Electrical', 'Roadwork', 'Sanitation', 'General Maintenance'];
  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('crews').get();
      if (mounted) {
        setState(() {
          _teams = snapshot.docs.map((doc) => {'id': doc.id, 'name': doc.data()['name']}).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching teams: $e');
      // Fallback for unauthenticated users if Firestore rules block read access
      if (mounted) {
        setState(() {
          _teams = [
            {'id': 'U3AAGR1bUGz6H0n5Cld6', 'name': 'Avengers'},
            {'id': 'team_alpha', 'name': 'Civil Works Team (Alpha)'},
            {'id': 'team_beta', 'name': 'Electrical Team (Beta)'},
            {'id': 'team_gamma', 'name': 'Sanitation Team (Gamma)'},
          ];
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      
      // Formatting phone number (assuming India +91 for now)
      String phone = _mobileController.text.trim();
      if (!phone.startsWith('+')) {
        phone = '+91$phone';
      }

      await authRepo.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: phone,
        role: _accountType != AccountType.citizen ? 'maintenance' : 'citizen',
        teamId: _accountType == AccountType.teamMember ? _selectedTeamId : null,
        teamName: _accountType == AccountType.newTeam ? _teamNameController.text.trim() : null,
        teamDomain: _accountType == AccountType.newTeam ? _selectedDomain : null,
      );
      
      // On success, navigate to home (OTP bypassed)
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: Failed to sign up: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                // Account Type Toggle
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton('Citizen', AccountType.citizen, theme),
                      _buildToggleButton('Team Member', AccountType.teamMember, theme),
                      _buildToggleButton('New Team', AccountType.newTeam, theme),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'First Name',
                        controller: _firstNameController,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Last Name',
                        controller: _lastNameController,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                CustomTextField(
                  label: 'Mobile Number',
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  hint: '10-digit number',
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 10) return 'Invalid number';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  validator: (value) {
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                
                // Team Member View
                if (_accountType == AccountType.teamMember) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Join a Team',
                      helperText: 'Select the municipal team you belong to',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    initialValue: _selectedTeamId,
                    items: _teams.isEmpty 
                      ? [const DropdownMenuItem<String>(value: '', child: Text('Loading teams...'))]
                      : _teams.map((team) {
                          return DropdownMenuItem<String>(
                            value: team['id'],
                            child: Text(team['name']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null && value.isNotEmpty) {
                        setState(() {
                          _selectedTeamId = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (_accountType == AccountType.teamMember && (value == null || value.isEmpty)) {
                        return 'Please select a team to join';
                      }
                      return null;
                    },
                  ),
                ],

                // New Team View
                if (_accountType == AccountType.newTeam) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Team Name',
                    controller: _teamNameController,
                    hint: 'e.g., Team Epsilon',
                    validator: (value) {
                      if (_accountType == AccountType.newTeam && (value == null || value.isEmpty)) {
                        return 'Team Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Team Domain / Skill',
                      helperText: 'Primary area of expertise',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    initialValue: _selectedDomain,
                    items: _domains.map((domain) {
                      return DropdownMenuItem<String>(
                        value: domain,
                        child: Text(domain),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDomain = value;
                      });
                    },
                    validator: (value) {
                      if (_accountType == AccountType.newTeam && (value == null || value.isEmpty)) {
                        return 'Please select a domain';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Next',
                  isLoading: _isLoading,
                  onPressed: _signUp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, AccountType type, ThemeData theme) {
    final isSelected = _accountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _accountType = type;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
              ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
              : null,
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
