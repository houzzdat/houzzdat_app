import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/services/geofence_service.dart';

enum AttendanceStatus { checkedOut, checkedIn }
enum ReportType { voice, text }

/// Attendance tab — check-in, daily report (checkout), and history.
/// Uses real GPS geofencing against the project's site coordinates.
class AttendanceTab extends StatefulWidget {
  final String accountId;
  final String userId;
  final String? projectId;

  const AttendanceTab({
    super.key,
    required this.accountId,
    required this.userId,
    this.projectId,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  final _geofenceService = GeofenceService();

  AttendanceStatus _status = AttendanceStatus.checkedOut;
  String? _activeAttendanceId;
  DateTime? _checkInTime;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  // Geofence state
  GeofenceResult? _geofenceResult;
  bool _isCheckingLocation = false;
  bool _isGeofenceExempt = false;

  // Project geofence config (fetched from DB)
  double? _siteLat;
  double? _siteLng;
  int _geofenceRadius = 200;
  bool _hasGeofenceConfig = false;
  String? _projectName;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadGeofenceConfig(),
      _loadAttendance(),
    ]);
    if (mounted) setState(() => _isLoading = false);
    // After config is loaded, auto-check location
    if (_hasGeofenceConfig && !_isGeofenceExempt) {
      _checkLocation();
    }
  }

  /// Fetch the project's geofence config and user's exempt flag.
  Future<void> _loadGeofenceConfig() async {
    try {
      // Fetch user's geofence_exempt flag
      final userRow = await _supabase
          .from('users')
          .select('geofence_exempt')
          .eq('id', widget.userId)
          .maybeSingle();

      if (userRow != null) {
        _isGeofenceExempt = userRow['geofence_exempt'] == true;
      }

      // Fetch project geofence coordinates
      if (widget.projectId != null) {
        final project = await _supabase
            .from('projects')
            .select('name, site_latitude, site_longitude, geofence_radius_m')
            .eq('id', widget.projectId!)
            .maybeSingle();

        if (project != null) {
          _projectName = project['name'];
          final lat = project['site_latitude'];
          final lng = project['site_longitude'];
          if (lat != null && lng != null) {
            _siteLat = (lat as num).toDouble();
            _siteLng = (lng as num).toDouble();
            _geofenceRadius = (project['geofence_radius_m'] as int?) ?? 200;
            _hasGeofenceConfig = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading geofence config: $e');
    }
  }

  Future<void> _loadAttendance() async {
    try {
      // Check for an open session (checked in but not out)
      final openSession = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', widget.userId)
          .isFilter('check_out_at', null)
          .order('check_in_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (openSession != null) {
        _status = AttendanceStatus.checkedIn;
        _activeAttendanceId = openSession['id'].toString();
        _checkInTime = DateTime.parse(openSession['check_in_at']);
      } else {
        _status = AttendanceStatus.checkedOut;
        _activeAttendanceId = null;
        _checkInTime = null;
      }

      // Load completed sessions for history
      final historyData = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', widget.userId)
          .not('check_out_at', 'is', null)
          .order('check_in_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _history = (historyData as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
    }
  }

  /// Check current GPS position against the project geofence.
  Future<void> _checkLocation() async {
    if (!_hasGeofenceConfig) return;
    setState(() => _isCheckingLocation = true);

    final result = await _geofenceService.checkPosition(
      siteLat: _siteLat!,
      siteLng: _siteLng!,
      radiusM: _geofenceRadius,
    );

    if (mounted) {
      setState(() {
        _geofenceResult = result;
        _isCheckingLocation = false;
      });
    }
  }

  /// Whether the check-in button should be enabled.
  bool get _canCheckIn {
    // Already checked in → no
    if (_status == AttendanceStatus.checkedIn) return false;
    // Exempt users can always check in
    if (_isGeofenceExempt) return true;
    // No geofence configured → allow check-in
    if (!_hasGeofenceConfig) return true;
    // Must be inside geofence
    return _geofenceResult?.status == GeofenceStatus.inside;
  }

  Future<void> _handleCheckIn() async {
    try {
      final insertData = <String, dynamic>{
        'user_id': widget.userId,
        'account_id': widget.accountId,
        'project_id': widget.projectId,
        'check_in_at': DateTime.now().toIso8601String(),
      };

      // Attach GPS coordinates if available
      if (_geofenceResult != null &&
          _geofenceResult!.latitude != null &&
          _geofenceResult!.longitude != null) {
        insertData['check_in_lat'] = _geofenceResult!.latitude;
        insertData['check_in_lng'] = _geofenceResult!.longitude;
        insertData['check_in_distance_m'] = _geofenceResult!.distanceMetres;
      }

      // Flag if user is exempt (checking in without geofence validation)
      if (_isGeofenceExempt && _hasGeofenceConfig) {
        insertData['geofence_overridden'] = true;
      }

      final result = await _supabase.from('attendance').insert(insertData).select().single();

      if (mounted) {
        setState(() {
          _status = AttendanceStatus.checkedIn;
          _activeAttendanceId = result['id'].toString();
          _checkInTime = DateTime.parse(result['check_in_at']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    }
  }

  void _handleSendDailyReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _DailyReportSheet(
        recorderService: _recorderService,
        accountId: widget.accountId,
        userId: widget.userId,
        projectId: widget.projectId,
        onReportSent: (reportType, {String? reportText, String? voiceNoteId}) async {
          Navigator.pop(sheetContext);

          try {
            await _supabase.from('attendance').update({
              'check_out_at': DateTime.now().toIso8601String(),
              'report_type': reportType == ReportType.voice ? 'voice' : 'text',
              'report_text': reportText,
              'report_voice_note_id': voiceNoteId,
            }).eq('id', _activeAttendanceId!);

            if (mounted) {
              setState(() {
                _status = AttendanceStatus.checkedOut;
                _activeAttendanceId = null;
                _checkInTime = null;
              });

              _loadAttendance();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Daily report sent! You are checked out.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to check out: $e')),
              );
            }
          }
        },
      ),
    );
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);
  String _formatDate(DateTime dt) => DateFormat('EEE, MMM d').format(dt);

  String _elapsedSinceCheckIn() {
    if (_checkInTime == null) return '';
    final diff = DateTime.now().difference(_checkInTime!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m}m on site';
  }

  // ────────────────────── BUILD ──────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A237E)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildLocationStatusCard(),
          const SizedBox(height: 24),
          if (_history.isNotEmpty) ...[
            Text('HISTORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1,
              )),
            const SizedBox(height: 12),
            ..._history.map((entry) => _buildHistoryCard(entry)),
          ],
        ],
      ),
    );
  }

  // ────────────────────── STATUS CARD ──────────────────────

  Widget _buildStatusCard() {
    final isCheckedIn = _status == AttendanceStatus.checkedIn;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Large visual status indicator
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCheckedIn
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.1),
              ),
              child: Icon(
                isCheckedIn ? Icons.check_circle : LucideIcons.logIn,
                size: 48,
                color: isCheckedIn ? Colors.green : const Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isCheckedIn ? 'ON SITE' : 'CHECKED OUT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isCheckedIn ? Colors.green.shade700 : const Color(0xFF424242),
              ),
            ),
            if (isCheckedIn && _checkInTime != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_formatTime(_checkInTime!)} — ${_elapsedSinceCheckIn()}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),
            if (!isCheckedIn) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.logIn, size: 22),
                  label: const Text('CHECK IN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _canCheckIn ? _handleCheckIn : null,
                ),
              ),
              if (!_canCheckIn && _geofenceResult != null) ...[
                const SizedBox(height: 10),
                _buildBlockedMessage(),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.send, size: 22),
                  label: const Text('SEND REPORT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCA28),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: _handleSendDailyReport,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Message shown when check-in is blocked due to geofence.
  Widget _buildBlockedMessage() {
    final result = _geofenceResult!;
    final distLabel = result.distanceMetres != null
        ? (result.distanceMetres! >= 1000
            ? '${(result.distanceMetres! / 1000).toStringAsFixed(1)}km'
            : '${result.distanceMetres!.round()}m')
        : '';

    String text;
    switch (result.status) {
      case GeofenceStatus.outside:
        text = 'You are $distLabel from ${_projectName ?? 'the site'}. Move within ${_geofenceRadius}m to check in.';
        break;
      case GeofenceStatus.permissionDenied:
        text = result.message;
        break;
      case GeofenceStatus.serviceDisabled:
        text = result.message;
        break;
      default:
        text = result.message;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.mapPinOff, size: 14, color: Colors.red.shade400),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
            style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
        ),
      ],
    );
  }

  // ────────────────────── LOCATION STATUS CARD ──────────────────────

  Widget _buildLocationStatusCard() {
    // No geofence configured for this project
    if (!_hasGeofenceConfig) {
      if (_isGeofenceExempt) {
        return _locationCard(
          icon: LucideIcons.shieldOff,
          iconColor: Colors.amber.shade700,
          bgColor: Colors.amber.shade50,
          title: 'Geofence Exempt',
          subtitle: 'You can check in from any location',
        );
      }
      return _locationCard(
        icon: LucideIcons.mapPin,
        iconColor: Colors.grey.shade500,
        bgColor: Colors.grey.shade50,
        title: 'No Site Boundary Set',
        subtitle: 'Location verification not required for this project',
      );
    }

    // Exempt user
    if (_isGeofenceExempt) {
      return _locationCard(
        icon: LucideIcons.shieldOff,
        iconColor: Colors.amber.shade700,
        bgColor: Colors.amber.shade50,
        title: 'Geofence Exempt',
        subtitle: 'You can check in from any location',
      );
    }

    // Currently detecting
    if (_isCheckingLocation) {
      return _locationCard(
        icon: LucideIcons.loader,
        iconColor: Colors.grey.shade600,
        bgColor: Colors.grey.shade50,
        title: 'Locating you...',
        subtitle: 'Acquiring GPS signal',
        trailing: const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A237E)),
        ),
      );
    }

    // No result yet
    if (_geofenceResult == null) {
      return _locationCard(
        icon: LucideIcons.mapPin,
        iconColor: Colors.grey.shade500,
        bgColor: Colors.grey.shade50,
        title: 'Location Not Checked',
        subtitle: 'Tap to verify your location',
        onTap: _checkLocation,
      );
    }

    // Result available
    final r = _geofenceResult!;

    switch (r.status) {
      case GeofenceStatus.inside:
        return _locationCard(
          icon: LucideIcons.mapPin,
          iconColor: Colors.green,
          bgColor: Colors.green.shade50,
          title: r.message,
          subtitle: '${_projectName ?? 'Site'} — ${_geofenceRadius}m radius',
          trailing: IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 18, color: Colors.grey.shade400),
            onPressed: _checkLocation,
          ),
        );

      case GeofenceStatus.outside:
        return _locationCard(
          icon: LucideIcons.mapPinOff,
          iconColor: Colors.red,
          bgColor: Colors.red.shade50,
          title: r.message,
          subtitle: 'Move within ${_geofenceRadius}m of ${_projectName ?? 'the site'}',
          trailing: IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 18, color: Colors.grey.shade400),
            onPressed: _checkLocation,
          ),
        );

      case GeofenceStatus.permissionDenied:
        return _locationCard(
          icon: LucideIcons.shieldAlert,
          iconColor: Colors.amber.shade700,
          bgColor: Colors.amber.shade50,
          title: 'Location Permission Required',
          subtitle: r.message,
          trailing: TextButton(
            onPressed: () => _geofenceService.openSettings(),
            child: const Text('SETTINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        );

      case GeofenceStatus.serviceDisabled:
        return _locationCard(
          icon: LucideIcons.wifiOff,
          iconColor: Colors.grey.shade600,
          bgColor: Colors.grey.shade100,
          title: 'GPS Disabled',
          subtitle: r.message,
          trailing: TextButton(
            onPressed: () => _geofenceService.openLocationSettings(),
            child: const Text('ENABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        );

      case GeofenceStatus.error:
        return _locationCard(
          icon: LucideIcons.alertTriangle,
          iconColor: Colors.orange,
          bgColor: Colors.orange.shade50,
          title: 'Location Error',
          subtitle: r.message,
          trailing: IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 18, color: Colors.grey.shade400),
            onPressed: _checkLocation,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Reusable location status card.
  Widget _locationCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: bgColor,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────── HISTORY CARD ──────────────────────

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final checkIn = DateTime.parse(entry['check_in_at']);
    final checkOut = DateTime.parse(entry['check_out_at']);
    final reportType = entry['report_type'];
    final isVoice = reportType == 'voice';
    final overridden = entry['geofence_overridden'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isVoice
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVoice ? LucideIcons.volume2 : LucideIcons.edit3,
                size: 20,
                color: isVoice
                    ? const Color(0xFF1A237E)
                    : const Color(0xFFFFCA28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(checkIn),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(checkIn)} — ${_formatTime(checkOut)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Location badge
            if (overridden)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Exempt',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
              ),
            Text(
              isVoice ? 'Voice' : 'Text',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Daily Report Bottom Sheet (unchanged)
// ══════════════════════════════════════════════════════════════

class _DailyReportSheet extends StatefulWidget {
  final AudioRecorderService recorderService;
  final String accountId;
  final String userId;
  final String? projectId;
  final Function(ReportType, {String? reportText, String? voiceNoteId}) onReportSent;

  const _DailyReportSheet({
    required this.recorderService,
    required this.accountId,
    required this.userId,
    this.projectId,
    required this.onReportSent,
  });

  @override
  State<_DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<_DailyReportSheet> {
  bool _isRecording = false;
  bool _isSending = false;
  final _textController = TextEditingController();
  bool _showTextInput = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceReport() async {
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isSending = true;
      });

      try {
        final audioBytes = await widget.recorderService.stopRecording();
        if (audioBytes != null && widget.projectId != null) {
          final url = await widget.recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: widget.projectId!,
            userId: widget.userId,
            accountId: widget.accountId,
          );

          String? voiceNoteId;
          if (url != null) {
            try {
              final note = await Supabase.instance.client
                  .from('voice_notes')
                  .select('id')
                  .eq('audio_url', url)
                  .single();
              voiceNoteId = note['id']?.toString();
            } catch (_) {}
          }

          widget.onReportSent(ReportType.voice, voiceNoteId: voiceNoteId);
        } else {
          setState(() => _isSending = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: $e')),
          );
        }
      }
    } else {
      final hasPermission = await widget.recorderService.checkPermission();
      if (!hasPermission) return;
      await widget.recorderService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  void _handleTextReport() {
    if (_textController.text.trim().isEmpty) return;
    widget.onReportSent(ReportType.text, reportText: _textController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY REPORT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            )),
          const SizedBox(height: 4),
          Text('Record a voice note or type your report',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isRecording ? LucideIcons.square : LucideIcons.mic, size: 20),
              label: Text(
                _isSending
                    ? 'SENDING...'
                    : _isRecording
                        ? 'STOP & SEND VOICE REPORT'
                        : 'RECORD VOICE REPORT',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSending ? null : _handleVoiceReport,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 16),

          if (!_showTextInput)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.edit3, size: 18),
                label: const Text('TYPE TEXT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                  side: const BorderSide(color: Color(0xFF1A237E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _showTextInput = true),
              ),
            )
          else ...[
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your daily report...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.send, size: 18),
                label: const Text('SEND TEXT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCA28),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleTextReport,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
