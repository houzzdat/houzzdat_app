import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/auth/screens/auth_wrapper.dart';

/// Purpose determines navigation after password is set.
enum SetPasswordPurpose {
  /// First login — user has temp password, already authenticated.
  /// After setting password → navigate to AuthWrapper → dashboard.
  firstLogin,

  /// Forgot password — user verified via OTP, session exists.
  /// After setting password → sign out → back to login screen.
  forgotPassword,
}

/// Screen for setting a new password.
///
/// Used after:
/// 1. First login with a temporary password (no OTP needed).
/// 2. Successful OTP verification during forgot-password flow.
class SetPasswordScreen extends StatefulWidget {
  final SetPasswordPurpose purpose;

  const SetPasswordScreen({
    super.key,
    required this.purpose,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a password';
    }
    if (value.trim().length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value.trim() != _passwordController.text.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Update password and clear the must_change_password flag in one call
      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text.trim(),
          data: {'must_change_password': false},
        ),
      );

      if (!mounted) return;

      if (widget.purpose == SetPasswordPurpose.forgotPassword) {
        // Sign out and send back to login
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (_) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated. Please sign in with your new password.'),
              backgroundColor: AppTheme.successGreen,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // First login — proceed to dashboard via AuthWrapper
        // The must_change_password flag is now false, so AuthWrapper will proceed normally
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (_) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Set password error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('same_password') ||
        message.contains('same password')) {
      return 'New password must be different from your current password.';
    }
    if (message.contains('weak_password') || message.contains('weak password')) {
      return 'Password is too weak. Use at least 8 characters with letters and numbers.';
    }
    if (message.contains('session_not_found') || message.contains('not authenticated')) {
      return 'Session expired. Please sign in again.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return 'Could not update password. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isFirstLogin = widget.purpose == SetPasswordPurpose.firstLogin;

    return PopScope(
      // Block back navigation for first login — user must set password
      canPop: !isFirstLogin,
      child: Scaffold(
        backgroundColor: AppTheme.primaryIndigo,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Icon(
                    isFirstLogin ? Icons.lock_open_rounded : Icons.lock_reset_rounded,
                    size: 80,
                    color: AppTheme.accentAmber,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // Title
                  Text(
                    isFirstLogin ? 'SET YOUR PASSWORD' : 'RESET PASSWORD',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.textOnPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Subtitle
                  Text(
                    isFirstLogin
                        ? 'Choose a strong password for your account'
                        : 'Enter your new password below',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // New Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'New Password', // UX-audit #12: explicit label
                      hintText: 'Min 6 characters',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password', // UX-audit #21
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: BorderSide.none,
                      ),
                      errorStyle: const TextStyle(color: AppTheme.accentAmber),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // Confirm Password field
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _setPassword(),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Confirm Password', // UX-audit #12: explicit label
                      hintText: 'Re-enter password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                        tooltip: _obscureConfirm ? 'Show password' : 'Hide password', // UX-audit #21
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: BorderSide.none,
                      ),
                      errorStyle: const TextStyle(color: AppTheme.accentAmber),
                    ),
                    validator: _validateConfirm,
                  ),

                  // Password requirements hint
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingS),
                    child: Text(
                      'At least 8 characters with letters and numbers',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXL),

                  // Set Password button
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
                      onPressed: _isLoading ? null : _setPassword,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isFirstLogin ? 'Set Password' : 'Reset Password',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),

                  // Back to login (forgot password only)
                  if (!isFirstLogin) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AuthWrapper()),
                            (_) => false,
                          );
                        }
                      },
                      child: Text(
                        'Back to Sign In',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
