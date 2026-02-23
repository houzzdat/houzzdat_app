import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/auth/screens/set_password_screen.dart';

/// OTP verification screen used for the forgot-password flow.
///
/// After the user enters the correct 6-digit code, they are
/// navigated to [SetPasswordScreen] to choose a new password.
class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(email: widget.email);
      if (mounted) {
        setState(() => _isResending = false);
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code resent to ${widget.email}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('OTP resend error: $e');
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = 'Could not resend code. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final token = _controllers.map((c) => c.text).join();
    if (token.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.email,
      );

      // OTP verified — session is now active. Navigate to set password.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SetPasswordScreen(
              purpose: SetPasswordPurpose.forgotPassword,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('OTP verify error: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = _getVerifyErrorMessage(e);
        });
        // Clear all fields on error
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  String _getVerifyErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('expired') || message.contains('otp_expired')) {
      return 'This code has expired. Please request a new one.';
    }
    if (message.contains('invalid') || message.contains('otp_disabled')) {
      return 'Invalid code. Please check and try again.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return 'Verification failed. Please check the code and try again.';
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-submit when all 6 digits are filled
    if (index == 5 && value.isNotEmpty) {
      final allFilled = _controllers.every((c) => c.text.isNotEmpty);
      if (allFilled) {
        _verifyOtp();
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    // Handle backspace on empty field → move to previous
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryIndigo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              const Icon(Icons.mark_email_read_rounded, size: 80, color: AppTheme.accentAmber),
              const SizedBox(height: AppTheme.spacingM),

              // Title
              Text(
                'VERIFY YOUR EMAIL',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.textOnPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Subtitle with email
              Text(
                'Enter the 6-digit code sent to',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: const TextStyle(
                  color: AppTheme.accentAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // 6-digit OTP input fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48,
                    height: 56,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 6,
                      right: index == 5 ? 0 : 6,
                    ),
                    child: KeyboardListener(
                      focusNode: FocusNode(), // wrapper focus node for key events
                      onKeyEvent: (event) => _onKeyEvent(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: const BorderSide(
                              color: AppTheme.accentAmber,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            borderSide: const BorderSide(
                              color: AppTheme.errorRed,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accentAmber, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.accentAmber, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingXL),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Verify Code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Resend code
              _isResending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : TextButton(
                      onPressed: _resendCountdown > 0 ? null : _resendOtp,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Resend Code (${_resendCountdown}s)'
                            : 'Resend Code',
                        style: TextStyle(
                          color: _resendCountdown > 0
                              ? Colors.white.withValues(alpha: 0.4)
                              : AppTheme.accentAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

              const SizedBox(height: AppTheme.spacingS),

              // Back to sign in
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
