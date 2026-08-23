import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../data/repositories/auth_repository.dart';
import '../widgets/primary_button.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;

  
  Timer? _timer;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _verifyPhoneNumber();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (mostly Android)
          await _linkCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? 'Verification failed';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            // if (resendToken != null) _resendToken = resendToken; // Removed unused _resendToken
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6 || _verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _linkCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid OTP or linking failed.';
      });
    }
  }

  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.linkPhoneCredential(credential);
      if (mounted) {
        context.go('/'); // Go back to root to resolve navigation based on auth state
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Mask phone number
    final maskedPhone = widget.phoneNumber.length > 4 
      ? '******${widget.phoneNumber.substring(widget.phoneNumber.length - 4)}'
      : widget.phoneNumber;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Mobile Number')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.security,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'OTP sent to $maskedPhone',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
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
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  hintStyle: TextStyle(letterSpacing: 8, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                ),
                onChanged: (val) {
                  if (val.length == 6) {
                    _verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Verify',
                isLoading: _isLoading,
                onPressed: _otpController.text.length == 6 ? _verifyOtp : null,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _countdown > 0 ? 'Resend OTP in $_countdown s' : 'Didn\'t receive code?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_countdown == 0)
                    TextButton(
                      onPressed: () {
                        _startCountdown();
                        _verifyPhoneNumber();
                      },
                      child: const Text('Resend'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
