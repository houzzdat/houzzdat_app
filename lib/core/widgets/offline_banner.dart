import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/connectivity_service.dart';

/// Persistent banner shown when the app is offline.
/// Listens to [ConnectivityService] and auto-hides when back online.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _connectivity = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _connectivity.startMonitoring();
    _connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connectivity.isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      color: AppTheme.warningOrange,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 18, color: Colors.white),
            const SizedBox(width: AppTheme.spacingS),
            const Expanded(
              child: Text(
                "You're offline. Changes will sync when connected.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            InkWell(
              onTap: () => _connectivity.checkNow(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
