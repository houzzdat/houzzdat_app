import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// UX-audit #11: First-login onboarding overlay with sequential coach marks.
///
/// Shows a series of hint tooltips on first few sessions, highlighting
/// key features like voice recording, action triage, and navigation.
///
/// Usage:
/// ```dart
/// OnboardingOverlay.maybeShow(
///   context,
///   key: 'manager_onboarding',
///   steps: [
///     OnboardingStep(title: 'Record Voice', subtitle: 'Tap the mic...', icon: Icons.mic),
///     OnboardingStep(title: 'Triage Actions', subtitle: 'Swipe to...', icon: Icons.checklist),
///   ],
/// );
/// ```
class OnboardingStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class OnboardingOverlay {
  OnboardingOverlay._();

  /// Shows the onboarding overlay if the user hasn't completed it yet.
  /// Returns true if overlay was shown, false if already completed.
  static Future<bool> maybeShow(
    BuildContext context, {
    required String key,
    required List<OnboardingStep> steps,
    int maxSessions = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCount = prefs.getInt('onboarding_$key') ?? 0;

    if (sessionCount >= maxSessions) return false;

    await prefs.setInt('onboarding_$key', sessionCount + 1);

    if (!context.mounted) return false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss onboarding',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: _OnboardingContent(
            steps: steps,
            onDismiss: () {
              Navigator.of(context).pop();
              // Mark as permanently dismissed
              prefs.setInt('onboarding_$key', maxSessions);
            },
          ),
        );
      },
    );

    return true;
  }
}

class _OnboardingContent extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onDismiss;

  const _OnboardingContent({
    required this.steps,
    required this.onDismiss,
  });

  @override
  State<_OnboardingContent> createState() => _OnboardingContentState();
}

class _OnboardingContentState extends State<_OnboardingContent> {
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentStep ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentStep
                          ? AppTheme.accentAmber
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  size: 48,
                  color: AppTheme.accentAmber,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // Next / Got it button
              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Got it!' : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Skip button
              if (!isLast) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
